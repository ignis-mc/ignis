#!/usr/bin/env bash
# Fails on missing or malformed docstrings in every package.
set -euo pipefail
cd "$(dirname "$0")/.."
for p in ignis; do
    mojo doc -I src -I third_party/protocol/src -I third_party/nethernet/src \
        --diagnose-missing-doc-strings --Werror -o /dev/null "src/$p"
done
