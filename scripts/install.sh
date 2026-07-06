#!/usr/bin/env sh
set -eu

repo="${LANSENTINEL_REPO:-lansentinel/lansentinel}"
version="${LANSENTINEL_VERSION:-latest}"
install_dir="${LANSENTINEL_INSTALL_DIR:-$HOME/.local/bin}"
bin_name="lansentinel"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "lansentinel installer needs '$1' on PATH" >&2
    exit 1
  fi
}

say() {
  printf '%s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need curl
need tar
need uname
need mktemp
need find

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"

case "$os" in
  linux) os="linux" ;;
  darwin) os="macos" ;;
  *) fail "unsupported os '$os'. install from source for now." ;;
esac

case "$arch" in
  x86_64|amd64) arch="x86_64" ;;
  aarch64|arm64) arch="arm64" ;;
  *) fail "unsupported architecture '$arch'. install from source for now." ;;
esac

target="${os}-${arch}"

if [ "$version" = "latest" ]; then
  base_url="https://github.com/$repo/releases/latest/download"
  display_version="latest"
else
  case "$version" in
    v*) tag="$version" ;;
    *) tag="v$version" ;;
  esac
  base_url="https://github.com/$repo/releases/download/$tag"
  display_version="$tag"
fi

archive="lansentinel-${target}.tar.gz"
url="$base_url/$archive"
tmp="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

say "installing lansentinel ${display_version} for ${target}"
say "downloading $url"

if ! curl -fsSL "$url" -o "$tmp/$archive"; then
  fail "could not download $archive. set LANSENTINEL_REPO=owner/repo if this is a fork, or install from source."
fi

if curl -fsSL "$base_url/lansentinel.sha256" -o "$tmp/lansentinel.sha256"; then
  if command -v grep >/dev/null 2>&1 && command -v sha256sum >/dev/null 2>&1; then
    (cd "$tmp" && grep "  $archive$" lansentinel.sha256 | sha256sum -c -) >/dev/null || fail "checksum verification failed"
    say "checksum verified"
  elif command -v grep >/dev/null 2>&1 && command -v shasum >/dev/null 2>&1; then
    expected="$(grep "  $archive$" "$tmp/lansentinel.sha256" | awk '{print $1}')"
    actual="$(shasum -a 256 "$tmp/$archive" | awk '{print $1}')"
    [ -n "$expected" ] || fail "checksum entry missing for $archive"
    [ "$expected" = "$actual" ] || fail "checksum verification failed"
    say "checksum verified"
  else
    say "checksum downloaded, but no supported sha256 tool was found"
  fi
else
  say "checksum not found, continuing without verification"
fi

tar -xzf "$tmp/$archive" -C "$tmp"
binary="$(find "$tmp" -type f -name "$bin_name" -perm -111 | head -n 1)"

if [ -z "$binary" ]; then
  fail "archive did not contain an executable lansentinel binary"
fi

mkdir -p "$install_dir"
cp "$binary" "$install_dir/$bin_name"
chmod +x "$install_dir/$bin_name"

say "installed $install_dir/$bin_name"

case ":$PATH:" in
  *":$install_dir:"*) ;;
  *) say "note: $install_dir is not on PATH" ;;
esac

if "$install_dir/$bin_name" --version >/dev/null 2>&1; then
  "$install_dir/$bin_name" --version
else
  say "installed, but version check did not complete"
fi
