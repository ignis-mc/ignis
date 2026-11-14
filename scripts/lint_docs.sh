#!/usr/bin/env bash
# Fails on malformed docstrings in every package. Docstrings are short (one
# line, more only when non-obvious) with no Args/Returns/Raises/Parameters
# sections, so --diagnose-missing-doc-strings, which demands them, is off.
set -euo pipefail
cd "$(dirname "$0")/.."
for p in ignis; do
    mojo doc -I src -I third_party/protocol/src -I third_party/nethernet/src \
        --Werror -o /dev/null "src/$p"
done
