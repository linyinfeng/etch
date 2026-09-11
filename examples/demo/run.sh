#!/usr/bin/env bash
# The whole flow: tangle, build and run the result, weave, drift check, and
# translating a real rustc error back into the document.
# Run with: nix develop -c examples/demo/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

LP=(cargo run --quiet --)
DOC=examples/demo/literate.typ
OUT=examples/demo/build

echo "== tangle =="
"${LP[@]}" tangle "$DOC" --out "$OUT"

echo "== run the tangled crate =="
cargo run --quiet --manifest-path "$OUT/Cargo.toml" > "$OUT/run.txt"
diff -u examples/demo/expected.txt "$OUT/run.txt" && echo "output matches the document"

echo "== weave (PDF in $OUT) =="
typst compile --root . "$DOC" "$OUT/demo.pdf"

# A reference line's indentation decides the indentation of the expanded chunk, so
# the woven document has to show it (regression: it used to render flush left).
echo "== weave: references keep their indentation =="
indent=$(typst eval '{ import "lit/lp.typ": ref-indent; ref-indent("    <<print-results>>") }')
if [ "$indent" != '"    "' ]; then
    echo "FAIL: reference indentation is lost when weaving (got $indent)" >&2
    exit 1
fi
echo "reference indent survives: $indent"

echo "== drift check =="
"${LP[@]}" tangle "$DOC" --out "$OUT" --check

echo "== which document line produced src/main.rs:6 =="
"${LP[@]}" map --file src/main.rs --line 6 --out "$OUT"

echo "== translate a real rustc error =="
sed -i 's/math::add(2, 3)/math::ad(2, 3)/' "$OUT/src/main.rs"
cargo build --manifest-path "$OUT/Cargo.toml" --message-format=short 2>&1 | "${LP[@]}" explain --out "$OUT" || true

echo "== restore =="
"${LP[@]}" tangle "$DOC" --out "$OUT" > /dev/null
"${LP[@]}" tangle "$DOC" --out "$OUT" --check && echo "document and generated code agree"
