#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.local/bin"

mkdir -p "$TARGET_DIR"
ln -sf "$SCRIPT_DIR/bin/deep-claude" "$TARGET_DIR/deep-claude"
ln -sf "$SCRIPT_DIR/bin/deep-cco" "$TARGET_DIR/deep-cco"
ln -sf "$SCRIPT_DIR/bin/deep-router" "$TARGET_DIR/deep-router"

cat <<EOF
Installed:
  $TARGET_DIR/deep-claude    (DeepSeek; or OpenRouter with --open-router)
  $TARGET_DIR/deep-cco       (requires nikvdp/cco)
  $TARGET_DIR/deep-router    (curate the OpenRouter model set; requires node)

Make sure this directory is on your PATH:
  export PATH="\$HOME/.local/bin:\$PATH"

Then run:
  deep-claude                          # DeepSeek
  deep-cco                             # sandboxed via cco
  deep-router pick                     # choose OpenRouter models (interactive)
  deep-claude --open-router            # Claude Code on your chosen OpenRouter model
EOF
