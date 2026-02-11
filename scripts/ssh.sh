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

# ── Connect ────────────────────────────────────────────────────

exec ssh -A \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$DEV_USER@$SERVER_IP" "$@"
