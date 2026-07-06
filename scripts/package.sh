#!/usr/bin/env sh
set -eu

PONYC="${PONYC:-ponyc}"
VERSION="${VERSION:-0.1.0}"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"

case "$os" in
  linux) os="linux" ;;
  darwin) os="macos" ;;
  *)
    echo "unsupported os for packaging: $os" >&2
    exit 1
    ;;
esac

case "$arch" in
  x86_64|amd64) arch="x86_64" ;;
  aarch64|arm64) arch="arm64" ;;
  *)
    echo "unsupported architecture for packaging: $arch" >&2
    exit 1
    ;;
esac

TARGET="${TARGET:-${os}-${arch}}"
NAME="lansentinel-v${VERSION}-${TARGET}"

if command -v make >/dev/null 2>&1; then
  make build PONYC="$PONYC"
else
  "$PONYC" src -o . --bin-name lansentinel
fi

rm -rf dist
mkdir -p "dist/$NAME"
cp lansentinel "dist/$NAME/"
cp README.md LICENSE "dist/$NAME/"
cp -R docs examples scripts/install.sh "dist/$NAME/"

(cd dist && tar -czf "$NAME.tar.gz" "$NAME")
cp "dist/$NAME.tar.gz" "dist/lansentinel-$TARGET.tar.gz"
cp "dist/$NAME/lansentinel" dist/lansentinel

if command -v sha256sum >/dev/null 2>&1; then
  (cd dist && sha256sum "$NAME.tar.gz" "lansentinel-$TARGET.tar.gz" > lansentinel.sha256)
elif command -v shasum >/dev/null 2>&1; then
  (cd dist && shasum -a 256 "$NAME.tar.gz" "lansentinel-$TARGET.tar.gz" > lansentinel.sha256)
else
  echo "warning: no sha256 tool found" >&2
fi

echo "Artifacts:"
ls -1 dist
