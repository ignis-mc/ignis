#!/usr/bin/env bash
# World interop between Dragonfly v0.11.6's mcdb provider and
# ignis.world.mcdb. Needs go and mojo on PATH; exits non-zero on mismatch.
set -euo pipefail
ulimit -c 0
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
work="$(mktemp -d /tmp/ignis-world-interop.XXXXXX)"
trap 'rm -rf "$work"' EXIT

(cd "$here" && go build -o "$work/go-tool" .)
mojo build -I "$root/src" -I "$root/test" -I "$root/third_party/protocol/src" \
    -I "$root/third_party/nethernet/src" -D ASSERT=all \
    "$here/worldtool.mojo" -o "$work/mojo-tool"
G="$work/go-tool"
M="$work/mojo-tool"
# The Mojo tool loads resources/ relative to the repository root.
cd "$root"

check() { # name expected actual
    if cmp -s "$2" "$3"; then
        echo "ok   $1 ($(wc -l <"$2") lines)"
    else
        echo "FAIL $1"
        diff "$2" "$3" | head -20
        exit 1
    fi
}

"$G" world-write "$work/go"
cp -r "$work/go" "$work/go-copy"
"$G" world-dump "$work/go" "$work/go-go.txt"
"$M" dump "$work/go-copy" "$work/mojo-go.txt"
check "Dragonfly writes, Mojo loads the same columns" "$work/go-go.txt" "$work/mojo-go.txt"

"$M" write "$work/mojo"
cp -r "$work/mojo" "$work/mojo-copy"
"$G" world-dump "$work/mojo" "$work/go-mojo.txt"
check "Mojo writes, Dragonfly loads the same columns" "$work/go-go.txt" "$work/go-mojo.txt"
"$M" dump "$work/mojo-copy" "$work/mojo-mojo.txt"
check "Mojo writes, Mojo loads the same columns" "$work/go-go.txt" "$work/mojo-mojo.txt"
check "committed Dragonfly dump is current" "$root/test/data/mcdb/dragonfly-world.txt" "$work/go-go.txt"
echo "all world interop checks passed"
