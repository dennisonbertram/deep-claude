#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.local/bin"

mkdir -p "$TARGET_DIR"
ln -sf "$SCRIPT_DIR/bin/deep-claude" "$TARGET_DIR/deep-claude"
ln -sf "$SCRIPT_DIR/bin/deep-cco" "$TARGET_DIR/deep-cco"

cat <<EOF
Installed:
  $TARGET_DIR/deep-claude
  $TARGET_DIR/deep-cco (requires nikvdp/cco)

Make sure this directory is on your PATH:
  export PATH="\$HOME/.local/bin:\$PATH"

Then run:
  deep-claude
  deep-cco           # sandboxed via cco
EOF
