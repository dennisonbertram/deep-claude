#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.local/bin"

mkdir -p "$TARGET_DIR"
ln -sf "$SCRIPT_DIR/bin/deep-claude" "$TARGET_DIR/deep-claude"

cat <<EOF
Installed:
  $TARGET_DIR/deep-claude

Make sure this directory is on your PATH:
  export PATH="\$HOME/.local/bin:\$PATH"

Get started (OpenRouter — the default):
  security add-generic-password -s deep-router -a openrouter -U -w   # store your key
  deep-claude pick                     # choose your models
  deep-claude                          # run Claude Code on them

Or a personal endpoint (DeepSeek-direct, local model, self-hosted):
  deep-claude endpoints add deepseek https://api.deepseek.com/anthropic DEEPSEEK_API_KEY
  deep-claude --endpoint deepseek --model deepseek-v4-pro
EOF
