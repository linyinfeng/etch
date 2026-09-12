#import "@local/lp:0.1.0": file

= This repository, and its seed

`lp` treats its output directory as its own and refuses to guess: every file under it
is produced by a declaration or listed in the `.lpignore` of its directory. Here the
output directory is the repository root, so what this document does *not* produce is
whatever is not the crate, the package or a control file — and the lock
files cargo and nix maintain, which no chunk has any business owning.

#file(".gitignore", ````gitignore
.lp
target

````)

#file(".lpignore", ````gitignore
/.git

/target
````)

== What git is asked to ignore

Everything under `tangled/` is generated, so the whole directory is ignored: the crate, the
package, the protect list and the maps. What is tracked at the root is the document,
the pointer, the pipeline, and this file. `README.md` is that pointer, and there is one of it: a second name for
the same text is a second name that can drift, which is the whole reason this file's text is a
pointer. The `.gitignore` is written as the list itself — ignore everything, then allow these — so it
cannot fall out of step with what the repository is. The seed is not tracked in the working tree
either: it is the
`tangled` branch of this same repository, which is the one place output can live without being a file next to the
document.

== Starting from nothing

A fresh clone holds four things and nothing else: this document, the pointer at the root that leads
here, the `.gitignore`, which says exactly that — ignore everything, allow these — and the pipeline
that hands each generation to the seed branch. The seed is a branch as well, and there is nothing
else: everything beyond these is produced.
Everything else is produced
by tangling — except the one thing this document cannot produce for itself, the binary that reads
it, because the package has to exist before the document can be evaluated at all.

That is the seed, and it is not a file in the tree: it is a branch. One whole older generation — a
crate and the package it is built with — sits at its root, ready to unpack:

```sh
tangled_ref=$(git rev-parse --verify --quiet tangled || git rev-parse --verify --quiet origin/tangled)
mkdir -p tangled
git archive "$tangled_ref" | tar -x -C tangled     # the previous generation, into tangled/
git init -q tangled                                # the generated code gets its own history
cargo build --manifest-path tangled/Cargo.toml
./tangled/target/debug/lp tangle lp.typ            # writes to tangled/, next to the document
cargo test --manifest-path tangled/Cargo.toml
```

A clone is enough; there is no second remote to fetch from. `origin/tangled` is the fallback for the
case where the clone knows the branch only by that name.

These commands assume `typst` and `cargo` are on the path, and the previous chapter is where the
argument for that lives: the environment is what the reader has, not something this document hands over.

The tangle writes to `tangled/` without being told to: when `--out` is not given it is the
directory `tangled` next to the document, because the document is what the output belongs to. The
older lp reads the declarations here and writes this generation over its own tree — crate, package,
protect list. Its own history is what makes it readable a generation later, which is the
whole trick: the seed was never a special artifact, only an older generation of this.

That tree is a copy that can be read on its own, and it is a repository, but it is not this
repository: nobody edits the generated code, and its first commit is a judgement about the program
rather than about the document. One generation per commit is worth recommending — the tree is a
whole program, so a diff across it says what the program did before and does now — and that is as
far as the recommendation goes. Nothing here commits, and nothing here should: when a generation is
worth keeping is the writer's call, not the tool's.

The tree declares its own ignore rules rather than leaving them to a reader: they say what the tool keeps
and what the build tools write, and a file that only changes when someone remembers to change it is a file
that goes stale — the published tree is built from a seed, and a hand-maintained file has no way to reach
it. Being output, it is written when it differs and compared by `--check` like everything else:

```gitignore
.lp
target

```

Write it, declare it in the protect list above next to `/.git` — they are the same kind of file,
settings of the inner repository rather than content of this document — and the tangle leaves it
alone.

After that the loop is the ordinary one: edit this document, tangle, test. While writing,

```sh
./tangled/target/debug/lp watch lp.typ --check-cmd 'cargo build --manifest-path tangled/Cargo.toml --message-format=short'
```

`tests/self.rs` is what keeps the loop honest: the binary this document builds has to be
able to reproduce the sources it was built from, so hand-editing `src/` or `tests/` fails
a test instead of quietly working.

One thing that trips people up once: this prose is Typst, not Markdown. Emphasis is one
star (`*like this*`); a doubled star is a warning, not bold. Inside a fence it does not
matter — that text is whatever its language says it is.

== Keeping the seed in step

The seed only ever reads, and it is output: the same tree the tangle writes, committed at the root
of its own branch instead of being kept in the working tree. Keeping it in step is part of building
this repository rather than part of using the tool: the pipeline does it on every change to the
document — it takes the previous generation as the seed, builds it, tangles this document, checks the
tree against it, and then hands the branch the result. Nothing about the generated code is checked
there: a program's tests are the program's business, not the document's. That business is written down
where it lives — the flake and the workflow are output too, and they describe the tree they
are tangled into. What this document can state is the property that has to hold —
the branch carries a generation that can read the document, and a generation only ever reads.

So it is output in the strict sense: never edited, never checked out, never worked in. A worktree of
it would be stale the moment the next generation is committed. Looking at it costs no worktree
either: `git show tangled:<path>` reads one file, `git archive tangled | tar -x -C <dir>` unpacks a
whole tree.

=== What the branch carries, and what it does not

The branch carries what the tree's own repository commits: the declared files, `Cargo.lock`, and
the tree's own `.gitignore`. The lock file is the one file in the seed that no declaration produces
— a pinned resolution is a decision, not a derivation — and the `.gitignore` is a setting of the
inner repository, protected next to `.git` for that reason. Everything else the tangle writes stays
out, and each for a reason worth being able to say:

- `.lpmap.json`, in every directory that received a file. The tool classifies it as a *control
  file* rather than content — the same list `--check` exempts — and it is derived from the document
  alone. The first tangle of a fresh clone writes it back.
- `.lp/`, the copy of the package unpacked next to a document so Typst can import it. Also
  derived: it is the declaration of the package, unpacked.
- `target/`, which the build produces rather than this document.

So the seed is the program, not the state around it: a generation to read, to build, and — in the
one case where that matters — one to bootstrap from. Being a program is also the test: if the
bootstrap in "Starting from nothing" runs green from the branch alone, the branch carries enough,
and nothing else needs a rule.

Only one property is required of the seed: it must be a generation that can read this document, and
one generation behind is enough. Being the current one is better, so refresh it whenever the tree
changes — which is exactly what `--check` cannot tell you, since it guards the tree, not the
branch.
