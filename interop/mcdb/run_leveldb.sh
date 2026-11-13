#!/usr/bin/env bash
# LevelDB interop between goleveldb (df-mc v1.1.9) and ignis.leveldb.
# Run from anywhere; needs go and mojo on PATH. Exits non-zero on mismatch.
set -euo pipefail
ulimit -c 0
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
work="$(mktemp -d /tmp/ignis-ldb-interop.XXXXXX)"
trap 'rm -rf "$work"' EXIT

seed="${SEED:-7}"
n="${N:-3000}"
(cd "$here" && go build -o "$work/go-tool" .)
mojo build -I "$root/src" -I "$root/test" -I "$root/third_party/protocol/src" \
    -I "$root/third_party/nethernet/src" -D ASSERT=all \
    "$here/ldbtool.mojo" -o "$work/mojo-tool"
G="$work/go-tool"
M="$work/mojo-tool"
"$G" ldb-expect "$seed" "$n" "$work"

check() { # name expected actual
    if cmp -s "$2" "$3"; then
        echo "ok   $1 ($(wc -l <"$2") keys)"
    else
        echo "FAIL $1"
        exit 1
    fi
}

last_log() { ls "$1"/*.log | sort | tail -1; }

"$G" ldb-write "$work/go" "$seed" "$n"
"$M" dump "$work/go" "$work/a.txt"
check "goleveldb writes, Mojo reads" "$work/expected.txt" "$work/a.txt"

"$M" write "$work/mojo" "$seed" "$n"
"$G" ldb-dump "$work/mojo" "$work/b.txt"
check "Mojo writes, goleveldb reads" "$work/expected.txt" "$work/b.txt"
"$M" dump "$work/mojo" "$work/b2.txt"
check "Mojo reopens after goleveldb rewrote the manifest" "$work/expected.txt" "$work/b2.txt"

"$G" ldb-write "$work/go-unclean" "$seed" "$n" unclean
cp -r "$work/go-unclean" "$work/go-unclean-torn"
"$M" dump "$work/go-unclean" "$work/c.txt"
check "goleveldb stops uncleanly, Mojo recovers the journal" "$work/expected.txt" "$work/c.txt"

"$M" write "$work/mojo-unclean" "$seed" "$n" unclean 2>/dev/null || true
cp -r "$work/mojo-unclean" "$work/mojo-unclean-torn"
cp -r "$work/mojo-unclean" "$work/mojo-unclean-self"
"$G" ldb-dump "$work/mojo-unclean" "$work/d.txt"
check "Mojo aborts, goleveldb recovers the journal" "$work/expected.txt" "$work/d.txt"
"$M" dump "$work/mojo-unclean-self" "$work/d2.txt"
check "Mojo aborts, Mojo recovers the journal" "$work/expected.txt" "$work/d2.txt"

log="$(last_log "$work/go-unclean-torn")"
truncate -s -3 "$log"
"$M" dump "$work/go-unclean-torn" "$work/e.txt"
check "goleveldb journal torn mid-record, Mojo drops the last batch" "$work/expected-torn.txt" "$work/e.txt"

log="$(last_log "$work/mojo-unclean-torn")"
truncate -s -3 "$log"
cp -r "$work/mojo-unclean-torn" "$work/mojo-unclean-torn-self"
"$G" ldb-dump "$work/mojo-unclean-torn" "$work/f.txt"
check "Mojo journal torn mid-record, goleveldb drops the last batch" "$work/expected-torn.txt" "$work/f.txt"
"$M" dump "$work/mojo-unclean-torn-self" "$work/f2.txt"
check "Mojo journal torn mid-record, Mojo drops the last batch" "$work/expected-torn.txt" "$work/f2.txt"
echo "all LevelDB interop checks passed"
