#!/usr/bin/env sh
set -eu

version="${PONYC_VERSION:-0.66.0}"
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"

case "$os" in
  linux) os_part="unknown-linux-ubuntu24.04" ;;
  *)
    echo "unsupported os for CI ponyc install: $os" >&2
    exit 1
    ;;
esac

case "$arch" in
  x86_64|amd64) arch_part="x86-64" ;;
  aarch64|arm64) arch_part="arm64" ;;
  *)
    echo "unsupported architecture for CI ponyc install: $arch" >&2
    exit 1
    ;;
esac

asset="ponyc-${arch_part}-${os_part}.tar.gz"
url="https://github.com/ponylang/ponyc/releases/download/${version}/${asset}"
root="${RUNNER_TEMP:-/tmp}/ponyc-${version}"
archive="$root/$asset"

rm -rf "$root"
mkdir -p "$root"

echo "downloading $url"
curl -fsSL "$url" -o "$archive"
tar -xzf "$archive" -C "$root"

ponyc="$(find "$root" -type f -name ponyc -perm -111 | head -n 1)"

if [ -z "$ponyc" ]; then
  echo "could not find ponyc in downloaded archive" >&2
  exit 1
fi

bin_dir="$(dirname "$ponyc")"

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$bin_dir" >> "$GITHUB_PATH"
fi

export PATH="$bin_dir:$PATH"
ponyc --version
