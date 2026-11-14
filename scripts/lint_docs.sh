#!/usr/bin/env bash
# Fails on missing docstrings in every package.
#
# Docstrings are one short line by project rule, without `Args:`,
# `Returns:`, `Raises:` or `Parameters:` sections, so only the "missing a
# doc string" diagnostics and errors count; the section warnings are dropped.
set -uo pipefail
cd "$(dirname "$0")/.."
status=0
for p in ignis; do
    out="$(mojo doc -I src -I third_party/protocol/src -I third_party/nethernet/src \
        --diagnose-missing-doc-strings -o /dev/null "src/$p" 2>&1)" || status=1
    bad="$(printf '%s\n' "$out" | grep -E 'missing a doc string|error:' -A2)"
    if [[ -n "$bad" ]]; then
        printf '%s\n' "$bad"
        status=1
    fi
done
exit $status
