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

# ── Ensure SSH agent has a key (needed for GitHub on the server) ─

if ! ssh-add -l &>/dev/null; then
  if [ -n "$SSH_PRIVATE_KEY" ] && [ -f "$SSH_PRIVATE_KEY" ]; then
    ssh-add "$SSH_PRIVATE_KEY"
  fi
fi

# ── Select server type ────────────────────────────────────────

select_server_type() {
  if ! command -v jq &>/dev/null; then
    red "jq is required for server type selection. Install with: brew install jq"
    exit 1
  fi

  local location="${TF_VAR_location:-nbg1}"
  local response
  response=$(curl -sf -H "Authorization: Bearer $HCLOUD_TOKEN" \
    "https://api.hetzner.cloud/v1/server_types?per_page=50") || {
    red "Failed to fetch server types from Hetzner API."
    exit 1
  }

  local options
  options=$(echo "$response" | jq -r --arg loc "$location" '
    [
      .server_types[]
      | select(.name | test("^(cpx|ccx)[0-9]"))
      | . as $st
      | ($st.prices[] | select(.location == $loc)) as $price
      | {
          name: $st.name,
          cores: $st.cores,
          memory: ($st.memory | tonumber | floor),
          disk: $st.disk,
          price: ($price.price_hourly.net | tonumber)
        }
    ]
    | sort_by(.price)[]
    | "\(.name)\t\(.cores) vCPU\t\(.memory) GB RAM\t\(.disk) GB disk\t€\(.price)/h"
  ' | column -t -s$'\t')

  if [ -z "$options" ]; then
    red "No matching server types found for location $location."
    exit 1
  fi

  local last_type_file="$PROJECT_DIR/.last_server_type"
  local fzf_opts=(
    --prompt="Select server type: "
    --header="NAME       CPU       RAM          DISK          PRICE"
    --height=~20 --reverse
  )

  if [ -f "$last_type_file" ]; then
    local last_type
    last_type=$(cat "$last_type_file")
    fzf_opts+=(--query "$last_type" --select-1)
  fi

  local selected
  selected=$(echo "$options" | fzf "${fzf_opts[@]}") || {
    red "No server type selected."
    exit 1
  }

  local name
  name=$(echo "$selected" | awk '{print $1}')
  echo "$name" > "$last_type_file"
  echo "$name"
}

if [ -t 0 ]; then
  SERVER_TYPE=$(select_server_type)
  green "Selected: $SERVER_TYPE"
else
  SERVER_TYPE="${TF_VAR_server_type:-cpx22}"
fi

# ── Terraform apply ────────────────────────────────────────────

echo "=== Creating dev server ==="
cd "$PROJECT_DIR"
export HCLOUD_TOKEN
export TF_VAR_ssh_public_key_path="$SSH_KEY_PATH"

# Initialize if needed
if [ ! -d .terraform ]; then
  terraform init -input=false
fi

terraform apply -var="server_active=true" -var="server_type=$SERVER_TYPE" -auto-approve

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
  sleep 2
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
golang_version: "${GO_VERSION:-1.24.2}"
rust_version: "${RUST_VERSION:-stable}"
node_version: "${NODE_VERSION:-22.x}"
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

# Ensure file ends with a newline before appending
[ -s "$SSH_CONFIG" ] && [ -n "$(tail -c1 "$SSH_CONFIG")" ] && echo >> "$SSH_CONFIG"

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
