#!/bin/sh
# One-shot: produced the Stage 1 self.typ by wrapping each source file in a
# `#file` declaration. Not part of the build — after Stage 1 the document is the
# truth and this script is history. See
# agent-notes/decisions/2026-09-11-self-hosting-layout.md.
#
# The fence is four backticks because the sources contain three-backtick Typst
# fixtures; a fence has to be longer than any run inside it.

set -eu
cd "$(dirname "$0")/../.."

lang() {
	case "$1" in
	*.rs) echo rust ;;
	*.toml) echo toml ;;
	*) echo "no language tag for $1" >&2 && exit 1 ;;
	esac
}

cat <<'HEADER'
// The lp tool describing itself: every file of the crate, as declarations.
//
// `lp tangle self.typ --out .` regenerates Cargo.toml, src/ and tests/; the crate
// is its own output (ADR D15). The declarations are a faithful transliteration of
// the frozen seed in bootstrap/ — chunks are not shared here yet, and nothing is
// inlined, so the tangled files are byte-identical to the seed.
//
// The seed, not this document, is what a broken toolchain falls back on:
//
//   nix develop -c cargo build --manifest-path bootstrap/Cargo.toml
//   nix develop -c ./bootstrap/target/debug/lp tangle self.typ --out .
//
// Editing this file by hand is fine; running this script is not. It exists to
// record how Stage 1 was cut, not to be re-run over an edited document.

#import "lit/lp.typ": chunk, file, rule
#show: rule

= The tool, in its own words

Every file below is a root chunk. `bootstrap/` holds the same bytes, frozen: the
seed has to stay compilable without the tool it ships.

HEADER

for file in Cargo.toml src/*.rs tests/*.rs; do
	printf '#file("%s", ````%s\n' "$file" "$(lang "$file")"
	cat "$file"
	printf '````)\n\n'
done
