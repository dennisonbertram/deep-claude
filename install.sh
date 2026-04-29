#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.local/bin"
TARGET="${TARGET_DIR}/deep-claude"

mkdir -p "$TARGET_DIR"
ln -sf "$SCRIPT_DIR/bin/deep-claude" "$TARGET"

cat <<EOF
Installed deep-claude at:
  $TARGET

Make sure this directory is on your PATH:
  export PATH="\$HOME/.local/bin:\$PATH"

Then run:
  deep-claude
EOF
