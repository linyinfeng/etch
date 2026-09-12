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

A fresh clone of this repository holds five things and nothing else: this document, the chapters it includes, the pointer at the
root that leads here, the `.gitignore` that says which of them git is told to keep, and the pipeline that hands
each generation to the seed branch. Everything else is produced by tangling — except the one thing this
document cannot produce for itself, the binary that reads it, because the package has to exist before the
document can be evaluated at all.

That is the seed, and it is not a file in the tree: it is a branch. This repository lives at
`https://github.com/linyinfeng/lp`, and the whole of what a bootstrap needs from it is that one
branch. Start from whichever of the two states you are in.

*From a clone.* A clone already knows the remote, and `origin/tangled` is the branch. The first line is
only the case where this clone has the branch under its own name too:

```sh
tangled_ref=$(git rev-parse --verify --quiet tangled || git rev-parse --verify --quiet origin/tangled)
mkdir -p tangled
git archive "$tangled_ref" | tar -x -C tangled     # the previous generation, into tangled/
git init -q tangled                                # the generated code gets its own history
```

*From these files and nothing else.* No repository, no remote, nothing that knows where the project
lives: make one, name this remote, and ask for that branch by name. `--depth 1` is enough, because the
seed is a snapshot rather than a history, and nothing from it is ever merged:

```sh
git init -q
git remote add origin https://github.com/linyinfeng/lp
git fetch --depth 1 origin tangled
mkdir -p tangled
git archive FETCH_HEAD | tar -x -C tangled
git init -q tangled
```

The pipeline that publishes each generation is not needed for this and is not in front of you: the
branch is the half that starts a reader, and a clone is enough for the half that publishes.

Both roads end in the same thing: one whole older generation — a crate and the package it is built
with — unpacked at the root of `tangled/`. Unpack it whole. One of its directories is load-bearing in
a way its name does not show: the crate embeds its `book/` at compile time with `include_dir!`, so a
tree with that directory pruned away does not build, and the error is a proc macro complaining about a
missing directory rather than a sentence about a skipped step.

Then build it, and let it read this document. These commands want `typst` and `cargo` on the path;
where they come from nix, that is `nix shell nixpkgs#typst nixpkgs#cargo nixpkgs#stdenv.cc -c
<command>`, and the chapter on the build environment is where the argument for that lives. The package
this document is written against declares the compiler it needs, so a Typst older than that refuses the
import with both versions in the message rather than half-evaluating the document:

```sh
cargo build --manifest-path tangled/Cargo.toml
./tangled/target/debug/lp tangle lp.typ            # writes to tangled/, next to the document
cargo test --manifest-path tangled/Cargo.toml
```

The first tangle is not a report on a tree that was already right. The seed is one generation behind,
so a few files come out as `wrote` instead of `ok` — the ones this document changed since that
generation, and the rest of the tree stays as it was. Everything is consistent when it finishes, and
`lp tangle lp.typ --check` is what says so.

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

=== From the document alone, without the seed

The two roads above both need the seed. This one does not, and it is the one to take when the branch
cannot be fetched at all — no network, or no credentials for a private repository — or when a reader
would rather not trust a binary built before its session began. It is also the shortest proof that this
document is what it claims to be: everything needed to rebuild the tool is in the document, and a reader
that is a program can do it. Three of the four steps are chapters of this book rather than inventions.

*Install the package first, because nothing else can happen until it exists.* The document imports its own
package at the top, so Typst cannot read the document until that package is somewhere Typst can find it —
which is the one place this road reads markup instead of evaluating it. The package is ten fragments of one
chapter, `chapters/package.typ`: the two it declares for `typst/lp.typ` and `typst/typst.toml`, and the
fragments those two reference. Pull them out, by hand or with a script, expand the `<<…>>` references
between them, and put the result where `--package-path` will point: `local/lp/0.1.0/lib.typ` and
`local/lp/0.1.0/typst.toml`. The check is immediate: a two-line document that imports the package either
compiles or does not.

Take the expansion rules from the chapter on expanding a reference rather than from a guess: a reference is
a whole line, the indentation of the reference indents its expansion, a blank line inside an indented
fragment stays blank, and a name resolves to every declaration of that name in document order — which is
what makes expansion recursive, and recursion is not optional.

*Then stop reading markup.* Ask the document for its declarations the way the tool does: one query, through
a wrapper document that includes the documents, with `--root` and `--package-path` set.

```sh
typst eval 'query(<lp-decl>).map(declaration => declaration.value)' \
  --in wrapper.typ --root . --package-path pkgs
```

The answer is JSON, and it carries both kinds of thing at once: the declarations, and the options — the
directory the book is carried in and the names of its files arrive as a declaration whose `lp` is
`"options"`. A reader that looks for declarations by scanning the markup instead of evaluating it will be
wrong exactly where Typst is interesting: a scanner that looks for `#chunk(` gets lost in nested fences,
and finds declarations that are inside Rust string literals instead of in the markup. That is why this tool
does not parse Typst at all, and it is why the road is drawn this way.

*Expand, and write.* Every `file` declaration is a root: expand it, give it its newline, write it where its
name says. Two details are worth having before rather than after. The text of a declaration is walked the
way `str::lines()` walks it, so a fence whose last line is empty does not contribute an empty line, and a
written file ends with exactly one newline. And the book has to be written too — its names are in the
options, and the crate embeds that directory at compile time, so a tree without it does not build.

*Then let the tool grade the bootstrapper.* Build the tree, and run the binary that your own expansion just
produced over the document it came from:

```sh
nix shell nixpkgs#typst nixpkgs#cargo nixpkgs#stdenv.cc -c cargo build --manifest-path tangled/Cargo.toml
nix shell nixpkgs#typst -c ./tangled/target/debug/lp tangle book/lp.typ --out .
```

Every file should come back `ok`. A `wrote` means the expansion rules were not quite this document's — and
the tool has just named the file, the line and the declaration to look at. That pass also writes the maps
beside the generated files, which the tree's own tests read; `cargo test` after it is the whole suite, and
the test that re-tangles this document into the tree it is running in is the same agreement, restated.

== Keeping the seed in step

The seed only ever reads, and it is output: the same tree the tangle writes, committed at the root
of its own branch instead of being kept in the working tree. Keeping it in step is part of building
this repository rather than part of using the tool: the pipeline does it on every change to the
document — it takes the previous generation as the seed, builds it, tangles this document, checks the
tree against it, and then hands the branch the result. That is the same four steps a reader runs by
hand in "Starting from nothing", with the pipeline's names for the same things; the tool the pipeline
uses for them is the seed's, one generation behind, for the same reason a reader's is. Nothing about
the generated code is checked there: a program's tests are the program's business, not the document's. That business is written down
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
