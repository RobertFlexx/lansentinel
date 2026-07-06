#!/usr/bin/env sh
set -eu

target="${TARGET:-linux-x86_64}"
version="${VERSION:-}"

if [ -z "$version" ]; then
  versioned_match="$(find dist -maxdepth 1 -type f -name "lansentinel-v*-${target}.tar.gz" | sort | head -n 1)"
else
  versioned_match="dist/lansentinel-v${version}-${target}.tar.gz"
fi

stable="dist/lansentinel-${target}.tar.gz"
versioned="$versioned_match"
checksums="dist/lansentinel.sha256"

if [ ! -s "$stable" ]; then
  echo "missing release archive: $stable" >&2
  exit 1
fi

if [ -z "$versioned" ] || [ ! -s "$versioned" ]; then
  echo "missing versioned release archive for target $target" >&2
  if [ -d dist ]; then
    find dist -maxdepth 1 -type f -print | sort >&2
  fi
  exit 1
fi

if [ ! -s "$checksums" ]; then
  echo "missing checksum file: $checksums" >&2
  exit 1
fi

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
