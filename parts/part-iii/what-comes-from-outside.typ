= What comes from outside, and how it moves

Most of this repository is this document: the code, the flake, the workflows, the dependency list and the
lock files are all fragments of it, and changing any of them is changing this book. What is left is what
the book leans on rather than contains — a compiler, crates, nix inputs, action pins — and this chapter is
where each one is written down, how it moves, and what complains when it should.

== Each outside thing, and where it is written

*The compiler.* Typst itself, and this document states no version for it. It used to, as a `compiler` line in
the package's manifest — but Typst reads that line only when it resolves a package by name, and the package
is imported by path, so the line would now be a sentence nobody reads.

The Typst that *builds* the tree is not a number here. It comes from nixpkgs through the tree's flake, and
the pin is the lock file below. The bootstrap's `nix shell nixpkgs#typst` is the exception, and on purpose:
that command is about the reader's machine rather than about the tree, and a reader's nixpkgs moves when the
reader moves it.

*The crates.* The dependency table is a fragment, in the chapter on the build environment, and the policy it
follows is argued there: a mature crate rather than a hand-written wheel, and a sentence per line saying
what the crate is for. The resolution is not a fragment: `Cargo.lock` is quoted verbatim in the appendix,
because a pinned resolution is a decision rather than a derivation, and nothing in the document produces it.

To move one: change the line in the table, let cargo resolve it — a build or a test does that — and paste the
new lock back into the appendix. Nothing checks a version number, and nothing should; what the checks catch
is a resolution that disagrees with the tree, which a tangle reports as a stale file like any other.

*The nix inputs.* Also a fragment, and also locked: the flake's `inputs` are declared here, and `flake.lock`
is quoted in the same appendix as the cargo lock. The graph is deliberately flat — the chapter on the
pipeline argues why — and the rule it follows is that an input which would bring its own nixpkgs is told to
follow ours instead.

To move nixpkgs, or any input with it: `nix flake update` in a built tree, then paste the new lock back.
`nix flake check` is what says whether the result still builds every promise the flake makes.

*The action pins.* Two places, and they are different kinds of place.

The tree's workflows are fragments of this document, in the chapter on the pipeline, and they carry the pins
of everything they run. This repository writes them as `@vN` — one number, no forty-character digest —
because a workflow here is read as much as it is run, and a hash is not readable. The oracle for what the
numbers are today is `pinact`, asked without writing anything:

```sh
nix shell nixpkgs#pinact -c pinact run -u --check .github/workflows/*.yml
```

`-u` asks for the newest version of each action; `--check` turns the answer into a report instead of an
edit. That is the reply to "has anything moved", and the pins are then moved by hand, in the form this
repository uses.

The pipeline is the other place, and it is the one file of this repository that is not a fragment of this
document: `.github/workflows/tangle.yml`, at the root, in the repository rather than in the tree. It has to
exist before anything else can be generated, because it is what generates — so no tangle can produce it, and
it is maintained by hand. Its pins are its own list rather than the tree's, and nothing derives one from the
other: an action that moves in one place has to be moved in the other by someone who knows both are there.

*The packages this document imports.* There are none from outside, and that is a decision rather than an
accident: the only import is the document's own package, by the path it sits at, because a package fetched
from a registry by name and version would be a copy nobody in this repository can see or pin. Nothing to
update, which is the point of the chapter on publishing.

== What the seed has to do with it

Any of these moves changes the tree a tangle writes, which means the seed branch is a generation behind from
that moment on. That is allowed, and it is the ordinary state after a dependency bump: the seed only ever
reads, one generation behind is enough, and the pipeline refreshes it on the next push to the document. A
bump does not need the seed to move first.

== What tells you it is time

No bot opens a pull request for a version bump in this repository, and nothing here looks for newer versions
on a schedule of its own. The one scheduled thing is the tree's own check — the workflow fragment in the
chapter on the pipeline runs it daily as well as on demand — and what it catches is the outside world moving
out from under a pin: a runner GitHub retired, an action that stopped existing, a nixpkgs that no longer
builds what it built last month. The three signals are:

- `nix flake check` fails, on a schedule or on a push. Usually that is the world moving, occasionally it is
  this repository moving.
- `pinact run -u --check` is not silent. Something numbered has a newer number.
- Typst refuses to read the package. That is the compiler line doing its job, aimed at a reader whose Typst
  is older than the one this document was last read with.

One thing is deliberately not a signal: the versions of the tools the machine in front of you happens to
have. Nothing here pins them, the bootstrap says as much, and what this repository pins is what the tree
builds with — which is what CI checks.
