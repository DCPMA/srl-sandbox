#!/usr/bin/env bash
# install.sh — Install srl-sandbox CLI and zsh completions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_PATH="/usr/local/bin/srl-sandbox"
COMPLETIONS_DIR="$HOME/.config/srl-sandbox/completions"

echo "Installing srl-sandbox..."

# Symlink CLI to /usr/local/bin
if [[ -L "$BIN_PATH" || -f "$BIN_PATH" ]]; then
    echo "  Removing existing $BIN_PATH"
    sudo rm -f "$BIN_PATH"
fi

chmod +x "$SCRIPT_DIR/srl-sandbox"
sudo ln -s "$SCRIPT_DIR/srl-sandbox" "$BIN_PATH"
echo "  Linked $BIN_PATH -> $SCRIPT_DIR/srl-sandbox"

# Set up completions
mkdir -p "$COMPLETIONS_DIR"
if [[ -f "$SCRIPT_DIR/completions/_srl-sandbox" ]]; then
    ln -sf "$SCRIPT_DIR/completions/_srl-sandbox" "$COMPLETIONS_DIR/_srl-sandbox"
    echo "  Linked completions -> $COMPLETIONS_DIR/_srl-sandbox"
fi

# Add fpath to .zshrc if not present
ZSHRC="$HOME/.zshrc"
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

echo ""
echo "Done! Restart your shell or run: source ~/.zshrc"
echo "Then try: srl-sandbox help"
