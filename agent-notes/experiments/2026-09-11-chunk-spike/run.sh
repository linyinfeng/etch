#!/usr/bin/env bash
# Reproduce the spike: weave (PDF + PNG) and tangle (out/hello.py), then check
# that the generated file still matches the document.
set -euo pipefail
cd "$(dirname "$0")"
TYPST=${TYPST:-typst}
"$TYPST" compile hello.typ hello.pdf
"$TYPST" compile --format png --ppi 110 hello.typ 'page-{p}.png'
python3 tangle.py hello.typ --out out
python3 out/hello.py | diff - expected.txt
python3 tangle.py hello.typ --out out --check
