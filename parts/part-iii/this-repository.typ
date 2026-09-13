#import "../../package/lib.typ": file

= This repository, and its seed

`lp` treats its output directory as its own and refuses to guess: every file in the tree it writes is
produced by a declaration or listed in the `.lpignore` of its directory. That tree is `tangled/`, one
directory next to the document. Everything else in the repository is a source file, and there are six kinds
of them: this document, its chapters, the package they are written with, the pointer at the root, the
`.gitignore` that tells git what to track at all, and the pipeline that turns each generation into the seed.

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

/examples/demo/build

/result

/target
````)

== What git is asked to ignore

Everything under `tangled/` is generated, so the whole directory is ignored: the crate, the package, the
protect list and the maps. What git does track is the document and its chapters, the package they import, the
pointer, the pipeline,
and this file. `README.md` is that pointer, and there is one of it: a second name for the same text is a second
name that can drift, which is the whole reason its text is a pointer. This `.gitignore` is written as the list
itself — ignore everything, then allow these — so it cannot fall out of step with what the repository is. The
seed is not tracked in the working tree either: it is the `tangled` branch of this same repository, which is
the one place output can live without being a file next to the document.

== Starting from nothing

A fresh clone of this repository holds six things and nothing else: this document, the chapters it includes,
the package the document is written with, the pointer at the root that leads here, the `.gitignore` that says
which of them git is told to keep, and the pipeline that hands each generation to the seed branch.
Everything else is produced by tangling — except the one thing this
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
<command>`, and the chapter on the build environment is where the argument for that lives.
Nothing here states a compiler floor: the document imports its package by path, so there is no manifest for
Typst to read a version out of, and an older Typst fails on the syntax it does not know, like any other
document:

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
which says what under the tree is nobody's to delete — the git directory itself, the demo's build directory,
and what a build leaves behind: nix's `result` symlink and cargo's directory.

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
package at the top, so Typst cannot read the document until that one file is on disk — which is the only
place this road reads markup instead of evaluating it. The package is nine fragments of one chapter,
`parts/part-ii/package.typ`, and it is a single file: `package/lib.typ`, the path the import names. Pull
those fragments out, by hand or with a script, and expand the `<<…>>` references between them. The check is
immediate: a document that imports it either evaluates or does not.

Take the expansion rules from the chapter on expanding a reference rather than from a guess: a reference is
a whole line, the indentation of the reference indents its expansion, a blank line inside an indented
fragment stays blank, and a name resolves to every declaration of that name in document order — which is
what makes expansion recursive, and recursion is not optional.

*Then stop reading markup.* Ask the document for its declarations the way the tool does: one query, through
a wrapper document that includes the documents, with `--root` set.

```sh
typst eval 'query(<lp-decl>).map(declaration => declaration.value)' \
  --in wrapper.typ --root .
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
produced over the document it came from — or ask it first, since a plan writes nothing:

```sh
nix shell nixpkgs#typst nixpkgs#cargo nixpkgs#stdenv.cc -c cargo build --manifest-path tangled/Cargo.toml
nix shell nixpkgs#typst -c ./tangled/target/debug/lp plan book/lp.typ --out .
nix shell nixpkgs#typst -c ./tangled/target/debug/lp tangle book/lp.typ --out .
```

The plan answers with a document that says what that pass would write — on a tree nobody has built yet, all of
it — and the tangle answers with one that says what it did: an empty `changed` means your expansion and this
document agree, and anything in `changed`, `drifted` or `missing` means they do not, with the file, the line
and the declaration named. `LP_LOG=debug` prints the same thing as the readout this book used to quote, `ok`
for a file that was already right and `wrote` for one that was not. That pass also writes the maps beside the
generated files, which the tree's own tests read; `cargo test` after it is the whole suite, and the test that
re-tangles this document into the tree it is running in is the same agreement, restated.

== Editing this book

The loop above is a reader's. This section is the writer's — the one who arrived with a task rather than with
curiosity: where a change goes, what else moves with it, and what catches you when it does not.

*A change goes in the chapter that explains it.* Not in `tangled/**`, which is the last pass's output:
`lp tangle lp.typ --check` fails on a file edited there, and `tests/self.rs` re-tangles this document and
compares it with the tree it is running in. A fragment is written in the section that argues for it, and it is
named the way the code names it, with its file as a prefix (`map: which chunk produced a line`) — because a
chunk name is global to the document, and two sections that declare one name are concatenated in document order
rather than refused. `lp list lp.typ` is the index to look in before inventing a name.

Three mechanical facts an editor needs: a line that is exactly `<<name>>` is a reference, and
`@<<name>>` is how to write one that is not (D17); the prose is Typst rather than Markdown, so emphasis is *one
star*; and a chapter that declares anything imports the package itself, because `#include` splices content
without sharing the includer's scope.

*Adding a chapter is a file, a heading and an include.* The file goes under `parts/`, in the part it belongs
to; it holds one `= Title`; and the root `lp.typ` gets one `#include` for it, placed where you want a reader to
meet it, because that list is the only place the order of this book exists. There is no third step: the book's
file list is derived from what the document reads, so an included chapter travels into the tree's `book/` with
no setting touched. The file name is the title's slug, and that much is a convention rather than a rule —
nothing checks that the two agree.

The one silent mistake in this repository is the `#include` someone forgot. A file under `parts/` that nobody
includes is not part of the document, so it is not part of the book, and nothing says a word: the tool knows
documents, not this repository's directories. A chapter that seems to have disappeared is worth looking for in
the include list first.

*A test chapter moves three counts.* Adding one to `tests/` also means the intro's list of reader paths,
*How the tests are written*'s five files, and the five names in *The example, which is this document* all say
the wrong number — five becomes six — and nothing checks any of them.

*What a finished change has to pass.* Tangle, then the same command with `--check` to refuse drift, then
`cargo test --manifest-path tangled/Cargo.toml`, then `nix flake check` inside `tangled/` for the tree's own
promises. The seed stays one generation behind until the pipeline refreshes it, and that is the ordinary state
rather than drift.

*Two habits worth having before believing yourself.* Re-measure every number you write: a count in prose is a
promise no check keeps, and the checks that hold the code still say nothing about it. And when a mechanism
changes, search the book for the story it used to tell — when this book was audited, thirty-six claims had gone
false, and nine of them described something that was no longer there — a function, a file, a whole chapter —
while the sentences describing it stayed. Neither habit is about style; both are what the audit found.

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
- `.lp/`, where a pass keeps the entry document it writes to ask a document its question. Also
  transient: the pass writes it, and removes it when the question is answered.
- `target/`, which the build produces rather than this document.

So the seed is the program, not the state around it: a generation to read, to build, and — in the
one case where that matters — one to bootstrap from. Being a program is also the test: if the
bootstrap in "Starting from nothing" runs green from the branch alone, the branch carries enough,
and nothing else needs a rule.

Only one property is required of the seed: it must be a generation that can read this document, and
one generation behind is enough. Being the current one is better, so refresh it whenever the tree
changes — which is exactly what `--check` cannot tell you, since it guards the tree, not the
branch.
