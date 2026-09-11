#!/usr/bin/env bash
# Temporary, for working on this repository: the repository carries no environment of its own
# (the flake was removed, D21), so every command needs the toolchain borrowed from nixpkgs.
# Delete this script when `lp execute` exists and can do it from the document instead.
#
#   agent-notes/dev.sh gates        # everything: tangle, tests, fmt, clippy, check, weave, demo
#   agent-notes/dev.sh test|fmt|clippy|tangle|check|demo|weave
#   agent-notes/dev.sh <any command>            # run it with the toolchain on PATH
#   agent-notes/dev.sh shell                    # just give me the toolchain and a shell
#
# Rust needs a linker as well as cargo (`linker cc not found` is what a bare cargo gets you),
# and typst is a hard dependency of both tangling and the tests.

set -euo pipefail
cd "$(dirname "$0")/.."

pkgs=(nixpkgs#typst nixpkgs#cargo nixpkgs#stdenv.cc nixpkgs#rustfmt nixpkgs#clippy nixpkgs#python3)
run() { nix shell "${pkgs[@]}" -c "$@"; }

case "${1:-}" in
gates)
	run bash -c '
		set -e
		./target/debug/lp tangle lp.typ --out . >/dev/null
		printf "tests  %s suites\n" "$(cargo test 2>&1 | grep -cE "^test result: ok")"
		cargo fmt --check && echo "fmt    ok"
		echo "clippy $(cargo clippy --all-targets 2>&1 | grep -cE "^(warning|error)" || true) findings"
		./target/debug/lp tangle lp.typ --out . --check >/dev/null && echo "check  ok"
		echo "strays $(./target/debug/lp tangle lp.typ --out . 2>&1 | grep -c "declared without a language" || true) (language), 0 expected"
		echo "weave  $(TYPST_PACKAGE_PATH=$PWD/.lp typst compile lp.typ /tmp/lp.pdf 2>&1 | grep -c warning || true) warnings"
		printf "demo   %s\n" "$(examples/demo/run.sh 2>&1 | tail -1)"
	'
	;;
test) run cargo test ;;
fmt) run cargo fmt --check ;;
clippy) run cargo clippy --all-targets ;;
tangle) run ./target/debug/lp tangle lp.typ --out . ;;
check) run ./target/debug/lp tangle lp.typ --out . --check ;;
list) run ./target/debug/lp list lp.typ ;;
demo) run examples/demo/run.sh ;;
weave)
	run env TYPST_PACKAGE_PATH="$PWD/.lp" typst compile lp.typ /tmp/lp.pdf
	echo "wrote /tmp/lp.pdf"
	;;
shell) run bash ;;
bootstrap)
	# what a fresh clone does: lay the seed down, build it, let it write this generation
	cp -r seed/. .
	run cargo build
	run ./target/debug/lp tangle lp.typ --out .
	run cargo test
	;;
"") sed -n '2,12p' "$0" ;;
*) run "$@" ;;
esac
