#!/usr/bin/env bash
# install.sh — Install srl-sandbox v2 CLI with zsh completions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPLETIONS_DIR="$HOME/.config/srl-sandbox/completions"
ZSHRC="$HOME/.zshrc"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

install_cli() {
    local name="$1"
    local bin_path="/usr/local/bin/${name}"

    if [[ -L "$bin_path" || -f "$bin_path" ]]; then
        echo "  Removing existing $bin_path"
        sudo rm -f "$bin_path"
    fi
    if [[ -f "$SCRIPT_DIR/$name" ]]; then
        chmod +x "$SCRIPT_DIR/$name"
        sudo ln -s "$SCRIPT_DIR/$name" "$bin_path"
        echo "  Linked $bin_path -> $SCRIPT_DIR/$name"
    fi
}

install_completion() {
    local name="$1"
    if [[ -f "$SCRIPT_DIR/completions/_${name}" ]]; then
        ln -sf "$SCRIPT_DIR/completions/_${name}" "$COMPLETIONS_DIR/_${name}"
        echo "  Linked completions -> $COMPLETIONS_DIR/_${name}"
    fi
}

echo ""
printf "  ${BOLD}${CYAN}srl-sandbox v2 installer${NC}\n"
echo ""

# Pre-flight checks
if command -v container &>/dev/null; then
    echo "  ✔ Apple Container CLI found"
else
    echo "  ⚠ Apple Container CLI not found"
    echo "    Install from: https://github.com/apple/container/releases"
fi

if command -v code &>/dev/null; then
    echo "  ✔ VS Code CLI found"
else
    echo "  ⚠ VS Code not found (optional — needed for Remote SSH)"
fi

echo ""
echo "  Installing srl-sandbox..."
install_cli "srl-sandbox"

mkdir -p "$COMPLETIONS_DIR"
install_completion "srl-sandbox"

# Completions fpath
FPATH_LINE='fpath+=(~/.config/srl-sandbox/completions)'

if [[ -f "$ZSHRC" ]]; then
    if ! grep -qF "$FPATH_LINE" "$ZSHRC"; then
        echo "" >> "$ZSHRC"
        echo "# srl-sandbox completions" >> "$ZSHRC"
        echo "$FPATH_LINE" >> "$ZSHRC"
        echo "autoload -Uz compinit && compinit" >> "$ZSHRC"
        echo "  Added completion path to $ZSHRC"
    else
        echo "  Completion path already in $ZSHRC"
    fi
else
    echo "  Warning: $ZSHRC not found. Add manually:"
    echo "    $FPATH_LINE"
    echo "    autoload -Uz compinit && compinit"
fi

# Start container system service
if command -v container &>/dev/null; then
    echo ""
    echo "  Starting container system service..."
    container system start 2>/dev/null && echo "  ✔ Container system started" \
        || echo "  ℹ Container system may already be running"
fi

echo ""
printf "  ${GREEN}Done!${NC} Restart your shell or run: source ~/.zshrc\n"
echo ""
echo "  Quick start:"
echo "    cd ~/Projects/myapp"
echo "    srl-sandbox                    # creates sandbox, opens VS Code"
echo ""
echo "  Other commands:"
echo "    srl-sandbox help               # full usage"
echo "    srl-sandbox build              # rebuild container image"
echo "    srl-sandbox list               # list sandboxes"
echo ""
