#!/usr/bin/env sh
set -eu

BIN="${LANSENTINEL:-./lansentinel}"

"$BIN" --scan 192.168.1.0/24 --ports common --save inventory.json
