#!/usr/bin/env bash
# Temporary, for working on this repository: the repository carries no environment of its own
# (the flake was removed, D21), so every command needs the toolchain borrowed from nixpkgs.
# Delete it whenever the environment has somewhere better to live.
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
		./tangled/target/debug/lp tangle lp.typ >/dev/null
		printf "tests  %s suites\n" "$(cargo test --manifest-path tangled/Cargo.toml 2>&1 | grep -cE "^test result: ok")"
		cargo fmt --manifest-path tangled/Cargo.toml --check && echo "fmt    ok"
		echo "clippy $(cargo clippy --manifest-path tangled/Cargo.toml --all-targets 2>&1 | grep -cE "^(warning|error)" || true) findings"
		./tangled/target/debug/lp tangle lp.typ --check >/dev/null && echo "check  ok"
		echo "strays $(./tangled/target/debug/lp tangle lp.typ 2>&1 | grep -c "declared without a language" || true) (language), 0 expected"
		echo "weave  $(TYPST_PACKAGE_PATH=$PWD/.lp typst compile lp.typ /tmp/lp.pdf 2>&1 | grep -c warning || true) warnings"
		printf "demo   %s\n" "$(bash tangled/examples/demo/run.sh 2>&1 | tail -1)"
		if [ -d tangled/.git ]; then echo "repo   tangled/ is its own repository"; else echo "repo   MISSING tangled/.git"; fi
	'
	;;
test) run cargo test --manifest-path tangled/Cargo.toml ;;
fmt) run cargo fmt --manifest-path tangled/Cargo.toml --check ;;
clippy) run cargo clippy --manifest-path tangled/Cargo.toml --all-targets ;;
tangle) run ./tangled/target/debug/lp tangle lp.typ ;;
check) run ./tangled/target/debug/lp tangle lp.typ --check ;;
list) run ./tangled/target/debug/lp list lp.typ ;;
demo) run bash tangled/examples/demo/run.sh ;;
weave)
	run env TYPST_PACKAGE_PATH="$PWD/.lp" typst compile lp.typ /tmp/lp.pdf
	echo "wrote /tmp/lp.pdf"
	;;
shell) run bash ;;
bootstrap)
	# what a fresh clone does: lay the seed down, make the tree a repository, build it, and let the
	# older lp write this generation into it
	cp -r seed/. .
	[ -d tangled/.git ] || git init -q tangled
	run cargo build --manifest-path tangled/Cargo.toml
	run ./tangled/target/debug/lp tangle lp.typ
	run cargo test --manifest-path tangled/Cargo.toml
	;;
"") sed -n '2,12p' "$0" ;;
*) run "$@" ;;
esac
