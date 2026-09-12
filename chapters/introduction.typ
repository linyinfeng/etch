#import "@local/lp:0.1.0": chunk

= Introduction

== What `lp` is

A document in Typst, written so that it declares its own program. A fragment of code is a *chunk*; a chunk that
is written to a file is a *file* declaration; a line that is exactly `<<name>>` is replaced by everything named
`name`. `lp tangle` reads those declarations — by evaluating the document, never by parsing Typst — expands the
references, and writes the tree they describe. `lp weave` renders the document itself, carrying the book inside
the page it renders. Everything else the tool does is in service of two questions a person asks constantly: which
declaration produced this line, and what has drifted since I last ran it.

The tool is small on purpose. It computes nothing about the languages in the tree, it never edits what it did not
write, and it has no opinion about how a program should be arranged. It is a way of keeping one source and two
readings of it, and the readings are a page and a working tree.

== Where the idea comes from

Knuth's literate programming, in 1984, put one demand on a program: that it be written for a person to read, with
the code quoted into the prose in the order the argument needs rather than the order the compiler needs. WEB
supplied the two directions — `tangle` to extract the program, `weave` to typeset the document — and the two
names are borrowed here without embarrassment. What WEB could not have was a cheap checker: the claim "the code
in this document is the program" was true because someone maintained it that way, and a document that slowly
stopped being true was nobody's build failure. A generated tree changes that. Drift becomes a test, and a test
that runs on every change is what lets a document make the strong claim instead of the modest one.

The other thing WEB could not have is this century's reader. A program that reads a source tree does not see the
prose at all, and it cannot be persuaded by an arrangement that only exists there. That is not a reason to give
up the arrangement; it is a reason to make the document the thing that is read, which is what a generated tree
makes possible.

== Why this exists, and what it does not promise

A program's argument — how it decomposes, why it decomposes that way, and the order in which someone should
come to understand it — is usually not an artifact at all. It lives in the author's head, in a review thread,
in a conversation, and nothing that is not written down can be maintained or improved. The move here is to
make that argument the source: the code is quoted into it, so the argument is what gets edited, reviewed and
diffed, and the program is a by-product of keeping it good. The order of that argument is part of the
artifact rather than a courtesy to the reader: the arrangement *is* the argument, written down where it can be
changed. There is no other way in — a change to the program
is a change to the book — and that is the whole of the forcing. Drift does not disappear. What changes is the
kind of thing that drifts: from "the code moved and the explanation stayed" to "the argument is no longer
true", which is a defect in the main artifact rather than in a commentary on it.

`lp` does not promise a good book. You can write terrible software and no compiler prevents it; you can write
a terrible book, and nothing here prevents it either. What the tool provides is a convenient process — one
source, a generated tree, provenance from a line back to the declaration that produced it, and a comparison
that fails when the two disagree — and convenience is what decides whether a book gets kept up at all. That
is the one thing here that is not Knuth's, whose reader is a human being, and it is what agentic coding
changes. An agent can find, read, rewrite, check and update a whole document in
minutes, which is not a thing a person does, so the maintenance cost that kept literate programming a
curiosity for forty years collapses. What an agent does not bring is the discipline; making the book the source
is how the discipline is imposed from outside.

Nor is anything here checked but the tree. What cannot be checked — the prose, the book, the order of its
argument — is not attempted, and the chapter on the rules is where that responsibility is written down: this
project would rather leave a thing undone than do it badly. So what this document presents is a position and
its demonstration rather than a metric, and it claims no improvement in what comes out. What it offers is a
change in what the artifact *is* — the argument first, the code as its by-product — and a process for turning
one into the other.

`lp` is the smallest tool that can carry that for Typst documents, and this book is written with it rather than
about it. The document you are reading is the program you are reading about, and the only gate in the
repository is on the tree, not on the prose.

== How to read this book

It has three parts, and they are three ways of asking one question. *Writing a literate program* is the method:
what the four claims cost, how a program is arranged when the reader decides the order, how to read what someone
else wrote that way, when it is not worth it, and what changes when the reader is not a person. *The tool* is the
design walk: what a declaration is, what a pass does with it, how the result is read back, and why each choice is
the one it is. *This repository* is the evidence: the tests, the build, the seed, and the lock files the document
carries verbatim.

Nothing has to be read in order. A chapter is a unit — it can be moved without moving its code, because nothing
here is in the order a compiler wants — so the useful question is not where to start but what you came for:

- *Someone who wants to write a literate program.* Start with *What literate programming is, in four claims*, then
  *Writing a literate program* and *Reading a literate program*. *When not to* and *Where this differs from WEB*
  are the two honest hedges.
- *Someone who wants to use the tool.* Start with *The command line, and what each command is for*, then *The
  package: what a declaration is* and *Expanding a reference* — with *Where each generated line came from* and
  *Reading a diagnostic back to the declaration* for the two questions above. Everything in Part II is written to
  be read in this direction.
- *Someone who has to get it running from nothing.* *This repository, and its seed* has the three roads: from a
  clone, from these files and nothing else, and from the document alone, without a seed at all. *The build
  environment* is what the commands expect, and *What comes from outside, and how it moves* is what to do when
  the outside moves.
- *Someone who has to maintain it.* *How the tests are written* and the five `tests/*.rs` chapters are the
  contract; *The program's own pipeline* and *This repository* are the machinery around it; *What comes from
  outside, and how it moves* is the update procedure.
- *Someone who wants the implementation, as a specification.* Part II in order, from *The package: what a
  declaration is* to *The rules*, which is the part that says what must stay true and why.
- *A reader that is a program.* *The reader that is not a person* is the argument, *This repository* has the road
  that needs no seed, and *The command line, and what each command is for* plus *The disk, and the log* are the
  two contracts it works against: standard output is data, standard error is the log.
- *Someone deciding whether to use this at all.* *When not to* first, then *Where this differs from WEB* and the
  four claims. The book would rather lose a reader early than have one who resents the cost later.
