= Quick start

Five minutes from nothing to a tree that passes its own tests. What this does *not* explain is why it is worth
doing — that is the introduction — and it is not the only way to begin: *This repository, and its seed* has
four roads: two of them start from the seed, one needs this document on disk and the seed not at all, and one
needs nothing but the rendering you are reading now.
Everything below assumes `nix` with flakes and a terminal. Rust and Typst come from the flake; nothing else has
to be installed for this.

The first step is the one thing the document cannot produce for itself: a binary that can read it, and this
rendering carries everything that step needs: its own source, and its fragments. No repository, no seed — the
road below takes the step from the document alone. A seed is the other job: it is what the pipeline reads to
keep this repository maintained, generation after generation, and *This repository, and its seed* is where
that is told.

```sh
mkdir -p tangled/book
nix shell nixpkgs#poppler-utils -c pdfdetach -saveall -o tangled/book etch.pdf
```

That is the book itself, file for file, because the rendering carries it. The tree is the rest, and the
rendering does not carry it as a file: it carries the fragments, each captioned with the path it is written to,
and *This repository, and its seed* has the road that reads them back into a tree. With a tree on disk, build
it and everything below is the same:

```sh
nix shell nixpkgs#typst nixpkgs#cargo nixpkgs#stdenv.cc -c cargo build --manifest-path tangled/Cargo.toml
```

Then ask what a pass would do. It writes nothing, and it answers on standard output with one JSON document —
which files it would write, which fragments nobody references, which files nothing accounts for. The log on
standard error says the same in prose, level by level; `ETCH_LOG=debug` is how a person reads it.

```sh
nix shell nixpkgs#typst -c ./tangled/target/debug/etch plan etch.typ
```

Then do it, and then check it the way the tree checks itself:

```sh
nix shell nixpkgs#typst -c ./tangled/target/debug/etch tangle etch.typ
nix shell nixpkgs#typst nixpkgs#cargo nixpkgs#stdenv.cc -c cargo test --manifest-path tangled/Cargo.toml
cd tangled && nix flake check --no-update-lock-file
```

The first `tangle` writes a handful of files rather than reporting everything `ok`: the seed is one generation
behind, and the log names what changed. From here the loop is the ordinary one — edit this document, tangle,
test — and a watcher of your choosing can run it: `watchexec -e typ -r -- ./tangled/target/debug/etch tangle
etch.typ`. Nothing in the tool watches files, and the chapter on what it does not do says why.

Two things are worth knowing before editing:

- The generated tree is output. `etch tangle etch.typ --check` compares it with the document and is what the tests
  use to prove the document still reproduces what it produced; `tests/self.rs` is that check, restated.
- `etch map --file src/main.rs --line 42` answers "which declaration produced this line", and `etch explain` rewrites
  a compiler's diagnostics into those names, so both directions back to the book exist.

Where to go from here: the introduction has a list that says which chapters are for which reader. If you are
changing the tool itself, *The rules* is the contract, and *tests/self.rs* is the invariant that will catch you.
