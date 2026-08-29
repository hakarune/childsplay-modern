#!/usr/bin/env bash
#
# serve.sh - serve web-canvas/ for local testing. ES modules need to be
# loaded over http://, not file://, so open a real server.
#
#   ./serve.sh [PORT]     (default 8080)
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

PORT="${1:-8080}"

if [ ! -d assets ] || [ -z "$(ls -A assets 2>/dev/null)" ]; then
  echo "note: web-canvas/assets/ is empty - run ./sync-assets.sh first" >&2
fi

echo "Childsplay web  ->  http://localhost:${PORT}/"
if command -v python3 >/dev/null 2>&1; then
  exec python3 -m http.server "$PORT"
elif command -v python >/dev/null 2>&1; then
  exec python -m http.server "$PORT"
elif command -v npx >/dev/null 2>&1; then
  exec npx --yes serve -l "$PORT" .
else
  echo "error: need python3 (or npx) to serve" >&2
  exit 1
fi
