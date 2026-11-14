#!/usr/bin/env bash
# Builds the server and the bots, starts the server offline on a free port
# and runs interop/bots/two_bots.mojo against it.
#
# Usage: scripts/e2e.sh [port]
set -euo pipefail
cd "$(dirname "$0")/.."

port="${1:-19190}"
inc=(-I src -I third_party/protocol/src -I third_party/nethernet/src)
mkdir -p build
mojo build --fp-mode contract=off "${inc[@]}" cmd/ignis/main.mojo -o build/ignis
mojo build --fp-mode contract=off "${inc[@]}" interop/bots/two_bots.mojo -o build/two_bots

dir="$(mktemp -d)"
trap 'kill "$pid" 2>/dev/null || true; rm -rf "$dir"' EXIT
./build/ignis -config "$dir/config.toml" -addr "127.0.0.1:$port" -offline >"$dir/server.log" 2>&1 &
pid=$!
for _ in $(seq 1 100); do
    grep -q '^READY' "$dir/server.log" && break
    sleep 0.2
done
grep -q '^READY' "$dir/server.log" || { cat "$dir/server.log"; exit 1; }

status=0
./build/two_bots "http://127.0.0.1:$port" 2>&1 | grep -v '^dial' || status=$?
echo "--- server log"
cat "$dir/server.log"
exit "$status"
