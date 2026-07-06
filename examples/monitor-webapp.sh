#!/usr/bin/env sh
set -eu

BIN="${LANSENTINEL:-./lansentinel}"

"$BIN" \
  --name WebApp=localhost:7070 \
  --slow 500ms \
  --interval 5s \
  --log lansentinel.log
