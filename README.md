# hcloud-dev

Ephemeral Hetzner Cloud dev server with persistent storage, pre-configured for AI-assisted development (Claude Code, OpenAI Codex) and Zed remote editing.

## How it works

```
┌─────────────────────────────────────────────────┐
│  Persistent (always exists)                     │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐ │
│  │ SSH Key  │  │ Firewall │  │ Volume (50GB) │ │
│  └──────────┘  └──────────┘  └───────────────┘ │
├─────────────────────────────────────────────────┤
│  Ephemeral (created/destroyed daily)            │
│  ┌──────────────────────────────────────┐       │
│  │ Server ──── Volume mounted at ~/work │       │
│  └──────────────────────────────────────┘       │
└─────────────────────────────────────────────────┘
```

Powering off a Hetzner server doesn't save costs — you pay for the allocated resources. Instead, this project **destroys the server** when you're done and recreates it the next morning. Your work directory lives on a persistent volume that survives server destruction.

## What you get

- Ubuntu 24.04 server with dev tools (git, build-essential, ripgrep, fzf, tmux, etc.)
- **Go** toolchain via [gantsign.golang](https://galaxy.ansible.com/gantsign/golang) (gopls, delve)
- **Rust** toolchain via [hurricanehrndz.rustup](https://galaxy.ansible.com/hurricanehrndz/rustup) (cargo-watch, cargo-edit)
- **Claude Code** and **OpenAI Codex** CLI pre-installed with API keys persisted on volume
- **[skills.sh](https://skills.sh/)** agent skills installed globally for Claude Code
- SSH agent forwarding for git operations with your local keys
- SSH config auto-managed — just `ssh dev`
- Zed remote development ready (Zed auto-installs its server component)
- Git identity carried over from your local machine

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6.0
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) (`brew install ansible`)
- Hetzner Cloud [API token](https://console.hetzner.cloud/)
- SSH key pair (`~/.ssh/id_ed25519` or `~/.ssh/id_rsa`)

## Quick start

```bash
# 1. Clone and enter the project
git clone <this-repo>
cd terraform-module-hcloud-dev

# 2. One-time setup — creates .env, checks prerequisites, runs terraform init
./scripts/setup.sh

# 3. Fill in your API tokens in .env (setup.sh will prompt you)

# 4. Create server and provision it
./scripts/up.sh
```

## Daily workflow

```bash
# Morning — create server (~3-5 min)
./scripts/up.sh

# Connect via SSH
ssh dev
# or
./scripts/ssh.sh

# Work with AI agents
claude           # Claude Code
codex            # OpenAI Codex

# Work with Go / Rust
go version       # Go is ready
cargo --version  # Rust is ready

# Install additional agent skills on the server
npx skills find              # search available skills
npx skills add <repo> -g     # install globally

# Connect with Zed: add "dev" as SSH remote in Zed

# Evening — destroy server, volume is preserved
./scripts/down.sh
```

## Scripts

| Script | What it does |
|--------|-------------|
| `./scripts/setup.sh` | One-time setup: checks prerequisites, creates `.env`, runs `terraform init` |
| `./scripts/up.sh` | Creates server, attaches volume, provisions with Ansible, updates SSH config |
| `./scripts/down.sh` | Destroys server (volume and data are preserved) |
| `./scripts/ssh.sh` | SSH into the server with agent forwarding |
| `./scripts/destroy-all.sh` | Destroys everything **including the volume** (data loss!) |

## Configuration

All configuration lives in `.env` (created from `.env.example` by `setup.sh`):

```bash
# Required
HCLOUD_TOKEN=your-hetzner-token

# Recommended (for AI agents)
ANTHROPIC_API_KEY=your-anthropic-key
OPENAI_API_KEY=your-openai-key

# Optional (auto-detected)
# SSH_PUBLIC_KEY_PATH=~/.ssh/id_ed25519.pub
# GIT_USER_NAME=Your Name
# GIT_USER_EMAIL=your@email.com
```

Everything else is auto-detected:
- **SSH key**: tries `~/.ssh/id_ed25519.pub`, then `~/.ssh/id_rsa.pub`
- **Git identity**: reads from your local `git config --global`

## Zed remote development

After `./scripts/up.sh`, connect from Zed:

1. Open Zed
2. Use "Connect to Server" (or add to settings):
   ```json
   "ssh_connections": [
     { "host": "dev" }
   ]
   ```
3. Zed will use your SSH config and auto-install its server component

## Terraform variables

Override defaults via `TF_VAR_` environment variables or by editing the terraform files:

| Variable | Default | Description |
|----------|---------|-------------|
| `server_active` | `true` | Whether the server should exist |
| `name` | `"dev"` | Resource name prefix |
| `location` | `"nbg1"` | Hetzner datacenter |
| `server_type` | `"cpx31"` | Server size (4 vCPU, 8 GB RAM) |
| `image` | `"ubuntu-24.04"` | OS image |
| `volume_size` | `50` | Persistent volume size in GB |
| `ssh_public_key_path` | `"~/.ssh/id_ed25519.pub"` | SSH public key path |
| `dev_username` | `"dev"` | Linux username |

## How API key persistence works

API keys are written to the persistent volume at `~/work/.devenv/api-keys.sh` and sourced from `.bashrc` on login. Since the volume survives server destruction, you only need to set the keys once — they persist across server recreations. Running `up.sh` again will update them if your local `.env` has changed.

## Ansible Galaxy roles

The provisioning uses two community roles (installed automatically by `setup.sh`):

| Role | What it installs |
|------|-----------------|
| [gantsign.golang](https://galaxy.ansible.com/gantsign/golang) | Go 1.24.2, gopls, delve |
| [hurricanehrndz.rustup](https://galaxy.ansible.com/hurricanehrndz/rustup) | Rust stable via rustup, cargo-watch, cargo-edit |

To customize versions or add cargo crates, edit `ansible/playbook.yml`.

## Agent skills (skills.sh)

[skills.sh](https://skills.sh/) is an open ecosystem of reusable AI agent capabilities by Vercel Labs. Skills are `SKILL.md` files that give agents procedural knowledge for specialized tasks.

The server comes with the official Claude Code skills pre-installed globally. To manage skills on the server:

```bash
npx skills find                    # search available skills
npx skills add <repo> -g           # install globally
npx skills list                    # list installed skills
npx skills update                  # update all skills
```

## Security notes

- The `.env` file contains secrets and is excluded from git via `.gitignore`
- API keys are stored on the volume with `0600` permissions
- SSH agent forwarding is enabled so your private keys never leave your machine
- The firewall restricts inbound traffic to SSH only
- Consider restricting SSH to your IP by editing the firewall rules in `main.tf`
