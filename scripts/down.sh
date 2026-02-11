#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }

SSH_CONFIG_MARKER="dev-server-managed"

# ── Load configuration ─────────────────────────────────────────

if [ ! -f "$PROJECT_DIR/.env" ]; then
  red ".env not found. Nothing to tear down?"
  exit 1
fi
source "$PROJECT_DIR/.env"

if [ -z "${HCLOUD_TOKEN:-}" ]; then
  red "HCLOUD_TOKEN is not set in .env"
  exit 1
fi

# ── Auto-detect SSH key path ───────────────────────────────────

SSH_KEY_PATH="${SSH_PUBLIC_KEY_PATH:-}"
if [ -z "$SSH_KEY_PATH" ]; then
  for key in ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub; do
    if [ -f "$key" ]; then
      SSH_KEY_PATH="$key"
      break
    fi
  done
fi

# ── Destroy server (keep volume) ──────────────────────────────

echo "=== Destroying dev server (volume is preserved) ==="
cd "$PROJECT_DIR"
export HCLOUD_TOKEN
export TF_VAR_ssh_public_key_path="${SSH_KEY_PATH:-~/.ssh/id_ed25519.pub}"

terraform apply -var="server_active=false" -auto-approve

# ── Clean up SSH config ────────────────────────────────────────

SSH_CONFIG="$HOME/.ssh/config"
if [ -f "$SSH_CONFIG" ] && grep -q "### BEGIN $SSH_CONFIG_MARKER ###" "$SSH_CONFIG" 2>/dev/null; then
  tmp=$(mktemp)
  awk "/### BEGIN $SSH_CONFIG_MARKER ###/{skip=1} /### END $SSH_CONFIG_MARKER ###/{skip=0; next} !skip" "$SSH_CONFIG" > "$tmp"
  mv "$tmp" "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
fi

echo
green "Server destroyed. Your work directory is safe on the persistent volume."
echo
echo "To start again tomorrow:"
echo "  ./scripts/up.sh"
