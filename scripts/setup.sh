#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }

echo "=== Dev Server Setup ==="
echo

# ── Check prerequisites ────────────────────────────────────────

missing=()
for cmd in terraform ansible-playbook ssh; do
  if ! command -v "$cmd" &>/dev/null; then
    missing+=("$cmd")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  red "Missing required tools: ${missing[*]}"
  echo
  echo "Install them with:"
  echo "  brew install terraform ansible"
  echo "  (ssh is included with macOS)"
  exit 1
fi

green "All prerequisites found."

# ── Create .env if missing ─────────────────────────────────────

if [ ! -f "$PROJECT_DIR/.env" ]; then
  if [ -f "$PROJECT_DIR/.env.example" ]; then
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    yellow "Created .env from .env.example — please fill in your API tokens."
    echo
    echo "  $PROJECT_DIR/.env"
    echo
    echo "Required:"
    echo "  HCLOUD_TOKEN        — Hetzner Cloud API token"
    echo
    echo "Recommended (for AI agents):"
    echo "  ANTHROPIC_API_KEY   — for Claude Code"
    echo "  OPENAI_API_KEY      — for OpenAI Codex"
    echo
    read -rp "Open .env in your editor now? [Y/n] " answer
    if [[ "${answer:-Y}" =~ ^[Yy]$ ]]; then
      "${EDITOR:-vim}" "$PROJECT_DIR/.env"
    fi
  else
    red ".env.example not found — cannot create .env"
    exit 1
  fi
fi

# ── Validate .env ──────────────────────────────────────────────

source "$PROJECT_DIR/.env"

if [ -z "${HCLOUD_TOKEN:-}" ]; then
  red "HCLOUD_TOKEN is not set in .env — this is required."
  exit 1
fi

green "HCLOUD_TOKEN is set."
[ -n "${ANTHROPIC_API_KEY:-}" ] && green "ANTHROPIC_API_KEY is set." || yellow "ANTHROPIC_API_KEY is not set (Claude Code won't be authenticated)."
[ -n "${OPENAI_API_KEY:-}" ]    && green "OPENAI_API_KEY is set."    || yellow "OPENAI_API_KEY is not set (Codex won't be authenticated)."

# ── Auto-detect SSH key ────────────────────────────────────────

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
  red "No SSH public key found. Create one with: ssh-keygen -t ed25519"
  exit 1
fi
green "SSH key: $SSH_KEY_PATH"

# ── Terraform init ─────────────────────────────────────────────

echo
echo "Initializing Terraform..."
cd "$PROJECT_DIR"
export HCLOUD_TOKEN
terraform init -input=false

echo
green "Setup complete!"
echo
echo "Next steps:"
echo "  ./scripts/up.sh     — create server and start working"
echo "  ./scripts/ssh.sh    — connect to the server"
echo "  ./scripts/down.sh   — destroy server (volume is preserved)"
