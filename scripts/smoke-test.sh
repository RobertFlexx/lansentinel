#!/usr/bin/env sh
set -eu

PONYC="${PONYC:-ponyc}"

if command -v make >/dev/null 2>&1; then
  make build PONYC="$PONYC"
else
  "$PONYC" src -o . --bin-name lansentinel
fi

./lansentinel --help >/dev/null
./lansentinel --version >/dev/null

if ./lansentinel --interval potato localhost:7070 >/tmp/lansentinel-invalid-duration.txt 2>&1; then
  echo "invalid duration unexpectedly succeeded" >&2
  exit 1
fi

if ./lansentinel localhost >/tmp/lansentinel-invalid-target.txt 2>&1; then
  echo "invalid target unexpectedly succeeded" >&2
  exit 1
fi

./lansentinel --once --json localhost:1 >/tmp/lansentinel-json.txt || true
./lansentinel --once --prometheus localhost:1 >/tmp/lansentinel-prometheus.txt || true
./lansentinel --once --fail-fast localhost:1 >/tmp/lansentinel-fail-fast.txt 2>&1 && {
  echo "fail-fast unexpectedly succeeded" >&2
  exit 1
}

./lansentinel --explain-scan >/tmp/lansentinel-explain-scan.txt
./lansentinel --router 192.168.1.1 --once --ports 1 --scan-timeout 100ms >/tmp/lansentinel-router-scan.txt
./lansentinel --scan 127.0.0.0/30 --ports 1 --json >/tmp/lansentinel-scan.json
./lansentinel --scan 127.0.0.0/30 --ports 1 --scan-mode arp >/tmp/lansentinel-scan-arp-human.txt
./lansentinel --scan 127.0.0.0/30 --ports 1 --scan-mode full --json >/tmp/lansentinel-scan-full.json
./lansentinel --scan 127.0.0.0/30 --ports 1 --scan-mode arp --json >/tmp/lansentinel-scan-arp.json
./lansentinel --scan 127.0.0.0/30 --ports 1 --save /tmp/lansentinel-inventory.json >/tmp/lansentinel-save.txt
./lansentinel --scan 127.0.0.0/30 --ports 1 --scan-mode full --save /tmp/lansentinel-inventory-full.json >/tmp/lansentinel-save-full.txt
test -f /tmp/lansentinel-inventory-full.json
./lansentinel --inventory /tmp/lansentinel-inventory.json >/tmp/lansentinel-inventory-show.txt

if ./lansentinel --scan 10.0.0.0/8 --ports 1 >/tmp/lansentinel-huge-scan.txt 2>&1; then
  echo "huge scan unexpectedly succeeded" >&2
  exit 1
fi

if ./lansentinel --scan 192.168.1.0/24 --scan-mode full --ports 1 >/tmp/lansentinel-full-large.txt 2>&1; then
  echo "large full scan unexpectedly succeeded without --allow-large-scan" >&2
  exit 1
fi

echo "Smoke tests completed."
