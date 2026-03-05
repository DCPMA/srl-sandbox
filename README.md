# srl-sandbox v2

Sandboxed development environments on macOS using [Apple Container](https://github.com/apple/container). Spin up isolated Linux containers for safe coding with LLM agents like [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Each container runs in its own lightweight VM with sub-second startup, direct IP networking, and proper filesystem isolation.

## Quick Start

```bash
# Install
./install.sh

# Launch sandbox for current project
cd ~/Projects/myapp
srl-sandbox
```

On first run, the tool builds a container image (Debian + Node.js + Claude Code + dev tools). Subsequent launches start in seconds.

## How It Works

1. **Launch** — Creates an OCI container from a pre-built image (Debian Bookworm with dev tools).
2. **Mount** — Project directory mounted read-write at `/mnt/project`. `~/.claude` and `~/.aws` mounted too.
3. **Connect** — Opens VS Code Remote SSH by default. Optionally: Claude Code, code-server, or plain shell.
4. **DNS** — Each container gets a hostname: `<name>.test` for easy access.

## Interactive Launch

```
$ srl-sandbox

━━ SRL Sandbox v2.0.0 ━━

  ▸ Sandbox: srl-myproject-a1b2 → /Users/you/Projects/myapp

  Use defaults? (VS Code Remote SSH) [Y/n]
```

Press **Enter** → VS Code opens connected to the container. Press **n** → configure:

```
  ━━ Configure ━━
  ↑↓ navigate · Space toggle · Enter confirm

  ▸ ☑  VS Code Remote SSH    Connect host VS Code via SSH
    ☐  Claude Code           Launch Claude Code in terminal
    ☐  Skip Permissions      --dangerously-skip-permissions
    ☐  Code Server           Browser VS Code (installed on demand)
    ☐  Shell Only            Drop into zsh shell
```

## Commands

| Command             | Description                                 |
| ------------------- | ------------------------------------------- |
| _(no command)_      | Launch/resume sandbox for current directory |
| `launch [path]`     | Launch/resume sandbox for a project         |
| `list`              | List all sandboxes with status              |
| `info <name>`       | Show detailed sandbox info                  |
| `ssh <name>`        | Shell into a running sandbox                |
| `exec <name> <cmd>` | Run a command inside a sandbox              |
| `stop <name\|all>`  | Stop a sandbox (or all)                     |
| `destroy <name>`    | Delete container and state file             |
| `sync <name>`       | Re-sync settings & configs                  |
| `build`             | Rebuild container image                     |
| `help`              | Show full usage                             |

## Launch Options

```
--name <name>            Override auto-generated sandbox name
--cpus <n>               CPU cores (default: 2)
--mem <n>                RAM in GiB (default: 4)
--mount <host>:<guest>   Mount additional directory (repeatable)
--no-sync                Skip settings/credentials sync
--headless               Don't open terminal/editor after launch
```

## What Gets Synced

| Item        | Source (macOS)                       | Destination (Container)               |
| ----------- | ------------------------------------ | ------------------------------------- |
| Project     | Project directory                    | `/mnt/project` (+ host-path symlink) |
| Claude      | `~/.claude/`                         | `/mnt/claude` → `~/.claude`          |
| AWS         | `~/.aws/`                            | `/mnt/aws` → `~/.aws`               |
| Git config  | `~/.gitconfig`, `~/.gitconfig.local` | `~/.gitconfig` (copied)              |
| GitHub auth | `gh auth token`                      | `gh auth login --with-token`          |
| SSH keys    | `~/.ssh/id_*.pub`                    | `~/.ssh/authorized_keys`             |

## Networking & DNS

Each container gets its own IP address and DNS hostname:

```
Container: srl-myproject-a1b2
       IP: 192.168.64.5
 Hostname: srl-myproject-a1b2.test
```

SSH config entries are auto-managed in `~/.ssh/config`, so you can:

```bash
ssh srl-myproject-a1b2                                    # direct SSH
code --remote ssh-remote+srl-myproject-a1b2 /mnt/project  # VS Code
```

## Isolation

Each container runs in its own lightweight VM:

- **Networking:** Isolated virtual network with direct IP
- **Filesystem:** Only explicit mounts (project, `.claude`, `.aws`)
- **No root access** on host — containers use `dev` user with sudo inside
- **SSH:** Key-based auth only (no passwords)

## Container Image

The sandbox uses a custom-built OCI image (`srl-sandbox:latest`) containing:

- Debian Bookworm (slim)
- Git, curl, jq, ripgrep, fd, build-essential, Python 3, zsh, tmux
- Node.js 24 (via nvm)
- Claude Code (`@anthropic-ai/claude-code`)
- GitHub CLI (`gh`)
- AWS CLI v2
- OpenSSH server

Rebuild anytime with: `srl-sandbox build`

## Code Server (Optional)

Code Server is **not pre-installed**. When selected in the launch menu, it's installed on-demand inside the running container. This keeps the base image lean.

## Requirements

- **macOS 26+** (Tahoe) with **Apple Silicon**
- [Apple Container CLI](https://github.com/apple/container) — install from GitHub releases
- [VS Code](https://code.visualstudio.com/) with [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) extension
- Python 3 (for JSON helpers — included with macOS)

## Project Structure

```
srl-sandbox              # V2 CLI (zsh)
Containerfile            # OCI image definition
install.sh               # Installer
README.md                # This file
completions/
  _srl-sandbox           # Zsh tab completions
```

## Migrating from V1

V2 replaces both `srl-sandbox` (Parallels) and `srl-sandbox-lite` (Lima):

| V1                         | V2                              |
| -------------------------- | ------------------------------- |
| Full VM (Parallels/Lima)   | OCI container (Apple Container) |
| Minutes to provision       | Sub-second startup              |
| Ansible / cloud-init setup | Containerfile (build once)      |
| Parallels license / Lima   | Free (Apple Container)          |
| Two separate tools         | Single unified tool             |

V1 sandboxes are not compatible with V2. Destroy V1 sandboxes before migrating:

```bash
srl-sandbox-lite stop all && srl-sandbox-lite destroy <names>
srl-sandbox stop all && srl-sandbox destroy <names>
```
