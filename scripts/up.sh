#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }

SSH_CONFIG_MARKER="dev-server-managed"

# ── Load configuration ─────────────────────────────────────────

if [ ! -f "$PROJECT_DIR/.env" ]; then
  red ".env not found. Run ./scripts/setup.sh first."
  exit 1
fi
source "$PROJECT_DIR/.env"

if [ -z "${HCLOUD_TOKEN:-}" ]; then
  red "HCLOUD_TOKEN is not set in .env"
  exit 1
fi

# ── Auto-detect settings ───────────────────────────────────────

SSH_KEY_PATH="${SSH_PUBLIC_KEY_PATH:-}"
if [ -z "$SSH_KEY_PATH" ]; then
  for key in ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub; do
    if [ -f "$key" ]; then
      SSH_KEY_PATH="$key"
      break
    fi
  done
fi

if [ -z "$SSH_KEY_PATH" ] || [ ! -f "$SSH_KEY_PATH" ]; then
  red "No SSH public key found."
  exit 1
fi

SSH_PRIVATE_KEY="${SSH_KEY_PATH%.pub}"
GIT_USER_NAME="${GIT_USER_NAME:-$(git config --global user.name 2>/dev/null || echo '')}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-$(git config --global user.email 2>/dev/null || echo '')}"

# ── Terraform apply ────────────────────────────────────────────

echo "=== Creating dev server ==="
cd "$PROJECT_DIR"
export HCLOUD_TOKEN
export TF_VAR_ssh_public_key_path="$SSH_KEY_PATH"

# Initialize if needed
if [ ! -d .terraform ]; then
  terraform init -input=false
fi

terraform apply -var="server_active=true" -auto-approve

# ── Read outputs ───────────────────────────────────────────────

SERVER_IP=$(terraform output -raw ipv4_address)
DEV_USER=$(terraform output -raw ssh_user)
VOLUME_DEVICE=$(terraform output -raw volume_linux_device)

echo
echo "Server IP: $SERVER_IP"
echo "User:      $DEV_USER"

# ── Wait for SSH ───────────────────────────────────────────────

echo
echo "Waiting for SSH to become available..."
attempts=0
max_attempts=60
while ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
          -o ConnectTimeout=5 -o BatchMode=yes \
          -i "$SSH_PRIVATE_KEY" \
          "$DEV_USER@$SERVER_IP" true 2>/dev/null; do
  attempts=$((attempts + 1))
  if [ $attempts -ge $max_attempts ]; then
    red "Timed out waiting for SSH (5 minutes). Server may still be booting."
    exit 1
  fi
  sleep 5
done
green "SSH is ready."

# ── Run Ansible ────────────────────────────────────────────────

echo
echo "=== Provisioning with Ansible ==="

# Write Ansible vars to temp file (handles spaces in values safely)
ANSIBLE_VARS_FILE=$(mktemp)
trap "rm -f $ANSIBLE_VARS_FILE" EXIT
cat > "$ANSIBLE_VARS_FILE" << VARS
dev_user: "$DEV_USER"
volume_device: "$VOLUME_DEVICE"
anthropic_api_key: "${ANTHROPIC_API_KEY:-}"
openai_api_key: "${OPENAI_API_KEY:-}"
git_user_name: "$GIT_USER_NAME"
git_user_email: "$GIT_USER_EMAIL"
VARS

ANSIBLE_CONFIG="$PROJECT_DIR/ansible/ansible.cfg" \
ansible-playbook "$PROJECT_DIR/ansible/playbook.yml" \
  -i "$SERVER_IP," \
  -u "$DEV_USER" \
  --private-key "$SSH_PRIVATE_KEY" \
  -e "@$ANSIBLE_VARS_FILE"

# ── Update SSH config ──────────────────────────────────────────

SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

# Remove old managed block if present
if grep -q "### BEGIN $SSH_CONFIG_MARKER ###" "$SSH_CONFIG" 2>/dev/null; then
  # Use a temp file for portable sed (macOS + Linux)
  tmp=$(mktemp)
  awk "/### BEGIN $SSH_CONFIG_MARKER ###/{skip=1} /### END $SSH_CONFIG_MARKER ###/{skip=0; next} !skip" "$SSH_CONFIG" > "$tmp"
  mv "$tmp" "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
fi

# Add new block
cat >> "$SSH_CONFIG" << EOF
### BEGIN $SSH_CONFIG_MARKER ###
Host dev
    HostName $SERVER_IP
    User $DEV_USER
    IdentityFile $SSH_PRIVATE_KEY
    ForwardAgent yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
### END $SSH_CONFIG_MARKER ###
EOF

# ── Done ───────────────────────────────────────────────────────

echo
green "=== Server is ready! ==="
echo
echo "Connect with:"
echo "  ssh dev"
echo "  ./scripts/ssh.sh"
echo
echo "Or open in Zed: Add 'dev' as an SSH remote"
echo
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "Claude Code: run 'claude' on the server"
fi
if [ -n "${OPENAI_API_KEY:-}" ]; then
  echo "Codex:       run 'codex' on the server"
fi
echo
echo "When done for the day:"
echo "  ./scripts/down.sh"
