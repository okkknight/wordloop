#!/bin/sh
set -eu

# Local development uses the same Node + SQLite API contract as VPS. Keep its
# data separate from the production-like fixture database used by other tools.
api_port="${WORDLOOP_LOCAL_API_PORT:-3011}"
database_path="${WORDLOOP_DB_PATH:-./data/wordloop.local.sqlite}"

PORT="$api_port" WORDLOOP_DB_PATH="$database_path" node server/index.mjs &
api_pid=$!
./node_modules/.bin/vinext dev "$@" &
web_pid=$!

cleanup() {
  kill "$web_pid" "$api_pid" 2>/dev/null || true
  wait "$web_pid" 2>/dev/null || true
  wait "$api_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

wait "$web_pid"
