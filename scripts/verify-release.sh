#!/usr/bin/env sh
set -eu

version="${VERSION:-}"

if [ -z "$version" ]; then
  version="$(awk -F'\"' '/^version =/ { print $2; exit }' pony.toml)"
fi

stable="dist/lansentinel-linux-x86_64.tar.gz"
versioned="dist/lansentinel-v${version}-linux-x86_64.tar.gz"
checksums="dist/lansentinel.sha256"

test -s "$stable"
test -s "$versioned"
test -s "$checksums"

if command -v sha256sum >/dev/null 2>&1; then
  (cd dist && sha256sum -c lansentinel.sha256)
elif command -v shasum >/dev/null 2>&1; then
  while read -r sum file; do
    actual="$(cd dist && shasum -a 256 "$file" | awk '{print $1}')"
    [ "$sum" = "$actual" ] || {
      echo "checksum failed for $file" >&2
      exit 1
    }
  done < "$checksums"
else
  echo "warning: no sha256 tool found, skipping checksum verification" >&2
fi

tmp="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

tar -xzf "$stable" -C "$tmp"
binary="$(find "$tmp" -type f -name lansentinel -perm -111 | head -n 1)"

test -n "$binary"
"$binary" --version

echo "release artifacts verified"
