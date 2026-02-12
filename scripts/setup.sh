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

# ── Default tool versions from local installs ───────────────────

set_env_default() {
  local key="$1"
  local value="$2"
  if [ -z "$value" ]; then
    return
  fi
  if [ -z "${!key:-}" ]; then
    printf -v "$key" '%s' "$value"
    export "$key"
  fi
  if grep -q "^${key}=" "$PROJECT_DIR/.env"; then
    if grep -q "^${key}=$" "$PROJECT_DIR/.env"; then
      tmp=$(mktemp)
      awk -v k="$key" -v v="$value" 'BEGIN{FS=OFS="="} $1==k{$0=k"="v} {print}' "$PROJECT_DIR/.env" > "$tmp"
      mv "$tmp" "$PROJECT_DIR/.env"
    fi
  else
    echo "${key}=${value}" >> "$PROJECT_DIR/.env"
  fi
}

GO_VERSION_LOCAL=""
if command -v go &>/dev/null; then
  GO_VERSION_LOCAL=$(go version | awk '{print $3}' | sed 's/^go//')
fi

RUST_VERSION_LOCAL=""
if command -v rustup &>/dev/null; then
  RUST_VERSION_LOCAL=$(rustup show active-toolchain 2>/dev/null | awk '{print $1}' | sed -E 's/-[a-z0-9_]+-[a-z0-9_]+-[a-z0-9_]+$//')
fi
if [ -z "$RUST_VERSION_LOCAL" ] && command -v rustc &>/dev/null; then
  RUST_VERSION_LOCAL=$(rustc -Vv | awk '/^release:/ {print $2}')
fi

NODE_VERSION_LOCAL=""
if command -v node &>/dev/null; then
  NODE_VERSION_LOCAL=$(node -p "process.versions.node")
fi

set_env_default GO_VERSION "$GO_VERSION_LOCAL"
set_env_default RUST_VERSION "$RUST_VERSION_LOCAL"
set_env_default NODE_VERSION "$NODE_VERSION_LOCAL"

if [ -z "${HCLOUD_TOKEN:-}" ]; then
  red "HCLOUD_TOKEN is not set in .env — this is required."
  exit 1
fi

green "HCLOUD_TOKEN is set."
[ -n "${ANTHROPIC_API_KEY:-}" ] && green "ANTHROPIC_API_KEY is set." || yellow "ANTHROPIC_API_KEY is not set (Claude Code won't be authenticated)."
[ -n "${OPENAI_API_KEY:-}" ]    && green "OPENAI_API_KEY is set."    || yellow "OPENAI_API_KEY is not set (Codex won't be authenticated)."
[ -n "${GITHUB_TOKEN:-}" ]      && green "GITHUB_TOKEN is set."      || yellow "GITHUB_TOKEN is not set (git push from server won't work)."

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
