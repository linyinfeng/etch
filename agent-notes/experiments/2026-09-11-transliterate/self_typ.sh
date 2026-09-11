#!/bin/sh
# One-shot: produced the Stage 1 self.typ by wrapping each file of the crate — and,
# later, the skill — in a `#file` declaration. Not part of the build: after Stage 1
# the document is the truth and this script is history. See
# agent-notes/decisions/2026-09-11-self-hosting-layout.md.
#
# Two mechanics it has to get right, both learned the hard way:
#   * the fence is one backtick longer than the longest run inside the file (the
#     sources contain three-backtick Typst fixtures, the skill contains four);
#   * a line that is exactly `<<name>>` becomes `@<<name>>`, because inside the
#     document it would be expanded — and a document that quotes the syntax has to
#     be able to show one (ADR D17).

set -eu
cd "$(dirname "$0")/../.."

lang() {
	case "$1" in
	*.rs) echo rust ;;
	*.toml) echo toml ;;
	*.md) echo markdown ;;
	*) echo "no language tag for $1" >&2 && exit 1 ;;
	esac
}

# One backtick more than the longest run in the file, never fewer than four.
fence() {
	awk '{
		line = $0
		while (match(line, /`+/)) {
			if (RLENGTH > max) max = RLENGTH
			line = substr(line, RSTART + RLENGTH)
		}
	} END { print substr("````````````````", 1, (max < 3 ? 3 : max) + 1) }' "$1"
}

# What the file contributes to the document, with reference-shaped lines escaped.
body() {
	sed -E 's/^([[:space:]]*)<<([^<>]+)>>[[:space:]]*$/\1@<<\2>>/' "$1"
}

cat <<'HEADER'
// The lp tool describing itself: the crate and the skill it ships, as declarations.
//
// `lp tangle self.typ --out .` regenerates Cargo.toml, src/, tests/ and the skill;
// the repository is its own output (ADR D15). The declarations are a faithful
// transliteration of the frozen seed in bootstrap/ — chunks are not shared here yet,
// and nothing is inlined, so the tangled files are byte-identical to the seed.
//
// Lines that look like references are escaped with `@` in the text below, because a
// document that quotes the syntax has to be able to show `<<name>>` on a line of its
// own without it being expanded (ADR D17).
//
// The seed, not this document, is what a broken toolchain falls back on:
//
//   nix develop -c cargo build --manifest-path bootstrap/Cargo.toml
//   nix develop -c ./bootstrap/target/debug/lp tangle self.typ --out .
//
// Editing this file by hand is fine; running this script is not. It exists to record
// how Stage 1 was cut, not to be re-run over an edited document.

#import "lit/lp.typ": chunk, file, rule
#show: rule

= The tool, in its own words

Every file below is a root chunk. `bootstrap/` holds the same bytes, frozen: the seed has
to stay compilable without the tool it ships.

HEADER

for file in Cargo.toml src/*.rs tests/*.rs \
	.agents/skills/literate-programming/SKILL.md \
	.agents/skills/literate-programming/references/example.md \
	.agents/skills/literate-programming/references/thinking.md
do
	printf '#file("%s", %s%s\n' "$file" "$(fence "$file")" "$(lang "$file")"
	body "$file"
	printf '%s)\n\n' "$(fence "$file")"
done
