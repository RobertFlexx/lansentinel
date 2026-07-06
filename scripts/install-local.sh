#!/usr/bin/env sh
set -eu

if [ ! -x dist/lansentinel ]; then
  echo "dist/lansentinel not found. Run scripts/package.sh first." >&2
  exit 1
fi

mkdir -p "$HOME/.local/bin"
cp dist/lansentinel "$HOME/.local/bin/lansentinel"
chmod +x "$HOME/.local/bin/lansentinel"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "Warning: $HOME/.local/bin is not in PATH." >&2 ;;
esac

echo "Installed $HOME/.local/bin/lansentinel"
