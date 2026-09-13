= The loop

With `etch` built, ask what a pass would do. It writes nothing, and it answers on standard output with one JSON
document — which files it would write, which fragments nobody references, which files nothing accounts for. The
log on standard error says the same in prose, level by level; `ETCH_LOG=debug` is how a person reads it.

```sh
nix shell nixpkgs#typst -c ./tangled/target/debug/etch plan etch.typ
```

Then do it, and then check it the way the tree checks itself:

```sh
nix shell nixpkgs#typst -c ./tangled/target/debug/etch tangle etch.typ
nix shell nixpkgs#typst nixpkgs#cargo nixpkgs#stdenv.cc -c cargo test --manifest-path tangled/Cargo.toml
cd tangled && nix flake check --no-update-lock-file
```

A tree bootstrapped from a rendering is exactly this document's, so the first `tangle` reports everything `ok`;
a tree built from the seed is one generation behind, and then the log names the handful of files that changed.
From here the loop is the ordinary one — edit this document, tangle, test — and a watcher of your choosing can
run it: `watchexec -e typ -r -- ./tangled/target/debug/etch tangle etch.typ`. Nothing in the tool watches files,
and the chapter on what it does not do says why.

Two things are worth knowing before editing:

- The generated tree is output. `etch tangle etch.typ --check` compares it with the document and is what the
  tests use to prove the document still reproduces what it produced; `tests/self.rs` is that check, restated.
- `etch map --file src/main.rs --line 42` answers "which declaration produced this line", and `etch explain`
  rewrites a compiler's diagnostics into those names, so both directions back to the book exist.

Where to go from here: the introduction has a list that says which chapters are for which reader. If you are
changing the tool itself, *The rules* is the contract, and *tests/self.rs* is the invariant that will catch you.
