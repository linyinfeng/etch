#!/usr/bin/env bash
# Temporary, for working on this repository: the repository carries no environment of its own
# (the flake was removed, D21), so every command needs the toolchain borrowed from nixpkgs.
# Delete it whenever the environment has somewhere better to live.
#
#   agent-notes/dev.sh gates        # everything: tangle, tests, fmt, clippy, check, weave, demo
#   agent-notes/dev.sh test|fmt|clippy|tangle|check|demo|weave|repo
#   agent-notes/dev.sh bootstrap|tangled       # what a clone does; refresh the tangled branch
#   agent-notes/dev.sh <any command>            # run it with the toolchain on PATH
#   agent-notes/dev.sh shell                    # just give me the toolchain and a shell
#
# Rust needs a linker as well as cargo (`linker cc not found` is what a bare cargo gets you),
# and typst is a hard dependency of both tangling and the tests.

set -euo pipefail

# This script lives with the notes and acts on the main working tree, which is where the document
# and its output are. Run it from anywhere — from a worktree of another branch, from main — and the
# first entry of `git worktree list` is the main one, by definition.
here=$(cd "$(dirname "$0")/.." && pwd)
main=$(git -C "$here" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')
cd "${main:-$here}"
[ "$PWD" = "$here" ] || echo "acting on $PWD (the main worktree)"

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
		# A whitelist in .gitignore re-includes whole directories; this is the line that says so
		# the moment it starts including build output.
		bad=$(git ls-files | grep -cE "(^|/)(target|out)/|[.](pdf|png)$" || true)
		[ "$bad" = 0 ] || { echo "tracked $bad build artifacts — a whitelist is leaking" >&2; exit 1; }
		echo "tracked no build artifacts"
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
tangled)
	# Write the current generation into the `tangled` branch. A temporary index and a temporary work
	# tree, built from the tree's own repository: `git add tangled` cannot work, because a
	# directory holding a .git is a repository and git will not add what is inside one.
	root=$PWD
	run ./tangled/target/debug/lp tangle lp.typ
	tmp=$(mktemp -d)
	idx=$(mktemp)
	rm -f "$idx"
	if git -C tangled rev-parse --verify --quiet HEAD >/dev/null; then
		git -C tangled archive HEAD | tar -x -C "$tmp"
	else
		echo "tangled $(git rev-parse --short refs/heads/tangled)  unchanged (tangled/ has no history yet)"
		rm -rf "$tmp" "$idx"
		exit 0
	fi
	(cd "$tmp" && GIT_DIR="$root/.git" GIT_WORK_TREE="$tmp" GIT_INDEX_FILE="$idx" git add -A .)
	tree=$(GIT_DIR="$root/.git" GIT_INDEX_FILE="$idx" git write-tree)
	rm -rf "$tmp" "$idx"
	current=$(git rev-parse --verify --quiet "refs/heads/tangled^{tree}" || true)
	if [ "$current" = "$tree" ]; then
		echo "tangled $(git rev-parse --short refs/heads/tangled)  unchanged  tree ${tree:0:7}"
		exit 0
	fi
	inner=$(git -C tangled rev-parse "HEAD^{tree}")
	[ "$inner" = "$tree" ] || {
		echo "tangled MISMATCH with tangled/ ($tree vs $inner)" >&2
		exit 1
	}
	# Nothing this document declares may be missing, and neither may the two members of the rule
	# that no declaration produces: a `.gitignore` edit that cuts inside a declared path, or drops
	# the lock file, hands a fresh clone a generation that is not the one the document describes.
	declared=$(run ./tangled/target/debug/lp tangle lp.typ --check | sed -e 's/\x1b\[[0-9;]*m//g' -e 's/^ok *//')
	missing=$(
		{
			printf '%s\n' "$declared"
			printf '%s\n' Cargo.lock .gitignore
		} | while read -r f; do
			[ -z "$f" ] && continue
			git cat-file -e "$tree:$f" 2>/dev/null || echo "$f"
		done
	)
	[ -z "$missing" ] || {
		echo "tangled declared but not in the tree: $missing" >&2
		exit 1
	}
	parent=$(git rev-parse --verify --quiet refs/heads/tangled || true)
	if [ -n "$parent" ]; then
		commit=$(git commit-tree "$tree" -p "$parent" -m "The generation this document writes")
	else
		commit=$(git commit-tree "$tree" -m "The generation this document writes")
	fi
	git update-ref refs/heads/tangled "$commit"
	echo "tangled $(git rev-parse --short refs/heads/tangled)  $(git ls-tree -r refs/heads/tangled --name-only | wc -l) files  tree ${tree:0:7}"
	;;
list) run ./tangled/target/debug/lp list lp.typ ;;
demo) run bash tangled/examples/demo/run.sh ;;
weave)
	run env TYPST_PACKAGE_PATH="$PWD/.lp" typst compile lp.typ /tmp/lp.pdf
	echo "wrote /tmp/lp.pdf"
	;;
shell) run bash ;;
bootstrap)
	# what a fresh clone does: unpack the tangled branch into tangled/, make the tree a repository,
	# build it, and let the older lp write this generation into it
	tangled_ref=$(git rev-parse --verify --quiet tangled || git rev-parse --verify --quiet origin/tangled)
	mkdir -p tangled
	run bash -c "git archive $tangled_ref | tar -x -C tangled"
	[ -d tangled/.git ] || git init -q tangled
	run cargo build --manifest-path tangled/Cargo.toml
	run ./tangled/target/debug/lp tangle lp.typ
	run cargo test --manifest-path tangled/Cargo.toml
	;;
"") sed -n '2,12p' "$0" ;;
*) run "$@" ;;
esac
