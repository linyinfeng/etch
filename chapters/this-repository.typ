#import "@local/lp:0.1.0": file

= This repository, and its seed

`lp` treats its output directory as its own and refuses to guess: every file in the tree it writes is
produced by a declaration or listed in the `.lpignore` of its directory. That tree is `tangled/`, one
directory next to the document. Everything else in the repository is a source file, and there are five kinds
of them: this document, its chapters, the pointer at the root, the `.gitignore` that tells git what to track
at all, and the pipeline that turns each generation into the seed.

Two of those files exist for the tree rather than for a reader, and this chapter declares them because the
tree has to carry them: the ignore rules the generated repository needs, and the protect list that says which
of its files are nobody's to delete. They are output like everything else, and the section below says why
they cannot be maintained by hand instead.

#file(".gitignore", ````gitignore
.lp
target

````)

#file(".lpignore", ````gitignore
/.git

/result

/target
````)

== What git is asked to ignore

Everything under `tangled/` is generated, so the whole directory is ignored: the crate, the package, the
protect list and the maps. What git does track is the document and its chapters, the pointer, the pipeline,
and this file. `README.md` is that pointer, and there is one of it: a second name for the same text is a second
name that can drift, which is the whole reason its text is a pointer. This `.gitignore` is written as the list
itself — ignore everything, then allow these — so it cannot fall out of step with what the repository is. The
seed is not tracked in the working tree either: it is the `tangled` branch of this same repository, which is
the one place output can live without being a file next to the document.

== Starting from nothing

A fresh clone holds five things and nothing else: this document, the chapters it includes, the pointer at the
root that leads here, the `.gitignore` that says which of them git is told to keep, and the pipeline that hands
each generation to the seed branch. Everything else is produced by tangling — except the one thing this
document cannot produce for itself, the binary that reads it, because the package has to exist before the
document can be evaluated at all.

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

A file that only changes when someone remembers to change it goes stale, and the published tree is built from
a seed — a hand-maintained file has no way to reach it. So the tree carries its own two settings instead: the
`.gitignore` above, which says what the tool keeps and what the build writes, and the `.lpignore` beside it,
which says the two things under the tree that are nobody's to delete — the git directory itself, and what a
build leaves behind: nix's `result` symlink and cargo's directory.

After that the loop is the ordinary one: edit this document, tangle, test. Nothing here watches the files — see
the chapter on what this tool does not do — so the loop is the command, and a watcher of your choosing is what
runs it:

```sh
watchexec -e typ -r -- ./tangled/target/debug/lp tangle lp.typ
```

`tests/self.rs` is what keeps the loop honest: the binary this document builds has to be
able to reproduce the sources it was built from, so hand-editing `src/` or `tests/` fails
a test instead of quietly working.

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
— a pinned resolution is a decision, not a derivation — and the `.gitignore` is there because the inner
repository needs it, not because a reader does. Everything else the tangle writes stays
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
