#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

red() { printf '\033[0;31m%s\033[0m\n' "$*"; }

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

# ── Ensure SSH agent has our key (needed for GitHub on the server) ─

SSH_KEY_PATH="${SSH_PUBLIC_KEY_PATH:-}"
if [ -z "$SSH_KEY_PATH" ]; then
  for key in ~/.ssh/id_ed25519 ~/.ssh/id_rsa; do
    if [ -f "$key" ]; then
      SSH_KEY_PATH="$key"
      break
    fi
  done
else
  SSH_KEY_PATH="${SSH_KEY_PATH%.pub}"
fi

if [ -n "$SSH_KEY_PATH" ] && [ -f "$SSH_KEY_PATH" ]; then
  ssh-add -q "$SSH_KEY_PATH" 2>/dev/null || true
fi

# ── Connect ────────────────────────────────────────────────────

exec ssh -A \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$DEV_USER@$SERVER_IP" "$@"
