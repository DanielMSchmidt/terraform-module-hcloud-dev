#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }

usage() {
  cat <<EOF
Usage: ./scripts/share.sh [SSH_PUBLIC_KEY_PATH]

Generate a connection command to share your dev server with someone.

If the other machine uses the same SSH key (e.g. your second computer),
just run without arguments:

  ./scripts/share.sh

To grant access to a friend with a different SSH key, pass their public key:

  ./scripts/share.sh /path/to/friend_id_ed25519.pub
  ./scripts/share.sh ~/.ssh/friend.pub
EOF
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

# ── Load configuration ─────────────────────────────────────────

if [ ! -f "$PROJECT_DIR/.env" ]; then
  red ".env not found. Run ./scripts/setup.sh first."
  exit 1
fi
source "$PROJECT_DIR/.env"
export HCLOUD_TOKEN="${HCLOUD_TOKEN:-}"

# ── Get server info from Terraform ─────────────────────────────

cd "$PROJECT_DIR"

STATUS=$(terraform output -raw server_status 2>/dev/null || echo "unknown")
if [ "$STATUS" != "running" ]; then
  red "Server is not running (status: $STATUS). Start it with: ./scripts/up.sh"
  exit 1
fi

SERVER_IP=$(terraform output -raw ipv4_address)
DEV_USER=$(terraform output -raw ssh_user)
SSH_PRIVATE_KEY=$(terraform output -raw ssh_private_key_path)

# ── Handle optional SSH key ────────────────────────────────────

FRIEND_KEY_PATH="${1:-}"

if [ -n "$FRIEND_KEY_PATH" ]; then
  if [ ! -f "$FRIEND_KEY_PATH" ]; then
    red "SSH public key not found: $FRIEND_KEY_PATH"
    exit 1
  fi

  FRIEND_KEY=$(cat "$FRIEND_KEY_PATH")

  # Validate it looks like an SSH public key
  if ! echo "$FRIEND_KEY" | grep -qE '^(ssh-(rsa|ed25519|dss)|ecdsa-sha2)'; then
    red "File does not look like an SSH public key: $FRIEND_KEY_PATH"
    exit 1
  fi

  echo "Adding SSH key to server..."
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i "$SSH_PRIVATE_KEY" \
    "$DEV_USER@$SERVER_IP" \
    "mkdir -p ~/.ssh && echo '$FRIEND_KEY' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

  green "Key added to server."
  echo
fi

# ── Output connection command ──────────────────────────────────

echo "Send this to your friend / run on your other machine:"
echo
echo "  ssh -A -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${DEV_USER}@${SERVER_IP}"
echo
yellow "Note: -A enables SSH agent forwarding, needed for git over SSH."
yellow "Make sure the SSH key is loaded into the agent first: ssh-add"
echo
