#!/usr/bin/env bash
# Fails on missing or malformed docstrings in every package. Docstrings are
# one short line by the owner's rule, so the diagnostics about missing
# Args/Returns/Raises/Parameters sections are ignored; every other warning
# (a public symbol without a docstring, a malformed one) fails.
set -euo pipefail
cd "$(dirname "$0")/.."
status=0
for p in ignis; do
    log="$(mktemp)"
    if ! mojo doc -I src -I third_party/protocol/src -I third_party/nethernet/src \
        --diagnose-missing-doc-strings -o /dev/null "src/$p" >"$log" 2>&1; then
        cat "$log"
        status=1
    fi
    if grep -E ': (warning|error): ' "$log" |
        grep -vE "but has no '(Args|Returns|Raises|Parameters)' in doc string" |
        grep -q .; then
        grep -E ': (warning|error): ' "$log" |
            grep -vE "but has no '(Args|Returns|Raises|Parameters)' in doc string"
        status=1
    fi
    rm -f "$log"
done
exit "$status"
