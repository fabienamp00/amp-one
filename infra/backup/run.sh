#!/usr/bin/env bash
set -euo pipefail

: ""
: ""

while true; do
  echo "[backup] starting daily pg_dump to /"
  TS=
  pg_dump -h db -U amp -d amp | zstd -19 -T0 | curl -X PUT \
    -H "Content-Type: application/octet-stream" \
    --upload-file - //server/pgdump-.sql.zst
  sleep 86400 & wait $!
done