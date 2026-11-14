#!/usr/bin/env bash
# Runs every test_*.mojo under test/ (or the paths given) and fails if any fails.
#
# Usage: scripts/run_tests.sh [-j N] [path ...]
#
# IGNIS_TEST_SHARD=i/n runs only every n-th file starting at index i (0-based),
# so CI can split the suite across runners.
set -uo pipefail

cd "$(dirname "$0")/.."

jobs="${IGNIS_TEST_JOBS:-4}"
if [[ "${1:-}" == "-j" ]]; then
    jobs="$2"
    shift 2
fi

roots=("$@")
if [[ ${#roots[@]} -eq 0 ]]; then
    roots=(test)
fi

mapfile -d '' files < <(find "${roots[@]}" -name 'test_*.mojo' -print0 | sort -z)
if [[ ${#files[@]} -eq 0 ]]; then
    echo "no test files found under: ${roots[*]}" >&2
    exit 1
fi

if [[ -n "${IGNIS_TEST_SHARD:-}" ]]; then
    shard="${IGNIS_TEST_SHARD%/*}"
    shards="${IGNIS_TEST_SHARD#*/}"
    picked=()
    for i in "${!files[@]}"; do
        if (( i % shards == shard )); then
            picked+=("${files[$i]}")
        fi
    done
    files=("${picked[@]}")
    echo "shard $shard of $shards: ${#files[@]} test files"
fi

run_one() {
    local file="$1"
    local log
    log="$(mktemp)"
    if mojo run --fp-mode contract=off -I src -I test -I third_party/protocol/src -I third_party/nethernet/src -D ASSERT=all "$file" >"$log" 2>&1; then
        grep -E '^Summary' "$log" | sed "s|^|ok   $file  |"
        rm -f "$log"
        return 0
    fi
    echo "FAIL $file"
    grep -v 'Crashpad' "$log" | sed 's/^/    /'
    rm -f "$log"
    return 1
}
export -f run_one

printf '%s\0' "${files[@]}" | xargs -0 -n 1 -P "$jobs" bash -c 'run_one "$0"'
status=$?
if [[ $status -ne 0 ]]; then
    echo "some test files failed" >&2
    exit 1
fi
echo "all ${#files[@]} test files passed"
