#!/usr/bin/env bash
# Fails if `mojo doc` reports an error or warning in any package.
#
# Docstrings are one short line without `Args:`/`Returns:`/`Raises:`/
# `Parameters:` sections, so `--diagnose-missing-doc-strings`, which demands
# those sections, is not used.
set -euo pipefail
cd "$(dirname "$0")/.."
for p in ignis; do
    mojo doc -I src -I third_party/protocol/src -I third_party/nethernet/src \
        --Werror -o /dev/null "src/$p"
done
