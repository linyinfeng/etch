#import "../../package/lib.typ": chunk

= Introduction

== A program's argument is usually not an artifact

How a program decomposes, why it decomposes that way, and the order in which someone should come to understand
it: that is the argument of a program, and it is usually not written down anywhere. It lives in the author's
head, in a review thread, in a conversation, in the shape of a pull request — places with no lifetime, no
diff, and no review of their own. Nothing that is not an artifact can be maintained, and nothing that cannot
be maintained stays true for long.

The code, meanwhile, is an artifact, and it is the only one. So the argument drifts away from it silently: the
compiler does not care what the code was *for*, and the reader who wanted to know is handed the code and asked
to reconstruct the reasoning.

== The bet: make the argument the source

Knuth's literate programming is the oldest serious answer to that, and his words are worth keeping:

> "Instead of imagining that our main task is to instruct a computer what to do, let us concentrate rather on
> explaining to human beings what we want a computer to do. The practitioner of literate programming can be
> regarded as an essayist, whose main concern is with exposition and excellence of style… He or she strives
> for a program that is comprehensible because its concepts have been introduced in an order that is best for
> human understanding." (*Literate Programming*, 1984)

What WEB supplied was the machinery for one text to be both the essay and the program: `tangle` rearranges the
fragments into the order a compiler requires, `weave` typesets the essay. The two names are borrowed here
without embarrassment. The move this book makes is to take the first half of that literally: *the argument is
the source*. The code is quoted into it, the tree is generated from it, and the argument is therefore what
gets edited, reviewed and diffed. The arrangement is not a courtesy to the reader — it *is* the argument,
written down where it can be changed — and there is no other way in: a change to the program is a change to
the book.

Drift does not disappear. What changes is the kind of thing that drifts: from "the code moved and the
explanation stayed" — which a comparison can catch, and here does — to "the argument is no longer true", which
is a defect in the main artifact rather than in a commentary on it.

== Why this is newly affordable

Because the maintainer of the artifact can now be a machine. An agent can find, read, rewrite, check and update
a whole book in minutes, which is not a thing a person does; the maintenance cost that kept WEB and CWEB niche
collapses. That is the one thing here that is not Knuth's — his reader is a human being — and it is what
agentic coding changes.

What an agent does not bring is the discipline. A fast writer will patch a fragment and leave the paragraph
above it saying the opposite, and nothing in a tree will notice. Making the book the source is how the
discipline is imposed from outside: the only way to change the program is to go through the argument that
explains it.

== What is not promised

Nothing here checks the prose, the book, or the order of its argument. That kind of check is not possible
today, so it is not attempted — this project would rather leave a thing undone than do it badly — and what
cannot be checked is the maintainer's responsibility, human or machine. The chapter on the rules is where that
responsibility is written down.

So what this document presents is a position and its demonstration rather than a metric. It claims no
improvement in what comes out: you can write terrible software, and no compiler prevents it; you can write a
terrible book, and nothing here prevents it either. What it offers is a change in what the artifact *is* — the
argument first, the code as its by-product — and a convenient process for turning one into the other.

== What `lp` is, in one paragraph

A document declares fragments of code as *chunks*, and the chunks that are written to files as *file*
declarations; a line that is exactly `<<name>>` is replaced by everything named `name`. `lp tangle` reads
those declarations — by evaluating the document, never by parsing Typst — expands the references and writes
the tree they describe. `lp weave` renders the document itself, carrying the book inside the page it renders.
Everything else serves the two questions a person asks constantly: which declaration produced this line, and
what has drifted since the last pass. The tool has no opinion about how a program should be arranged, computes
nothing about the languages in the tree, and never edits what it did not write.

== How to read this book

It has three parts, and they are three ways of asking one question. *Writing a literate program* is the method:
what the four claims cost, how a program is arranged when the reader decides the order, how to read what someone
else wrote that way, when it is not worth it, and what changes when the reader is not a person. *The tool* is
the design walk: what a declaration is, what a pass does with it, how the result is read back, and why each
choice is the one it is. *This repository* is the evidence: the tests, the build, the seed, and the lock files
the document carries verbatim.

*Quick start* is five minutes long and gets you from nothing to a tree that passes its own tests. Nothing else
has to be read in order: a chapter is a unit, and it can be moved without moving its code, because nothing here
is in the order a compiler wants. So the useful question is not where to start but what you came for:

- *Someone who wants to write a literate program.* *What literate programming is, in four claims*, then
  *Writing a literate program* and *Reading a literate program*; *When not to* and *Where this differs from WEB*
  are the two honest hedges.
- *Someone who wants to use the tool.* *The command line, and what each command is for*, then *The package: what
  a declaration is* and *Expanding a reference*, with *Where each generated line came from* and *Reading a
  diagnostic back to the declaration* for the two questions above.
- *Someone who has to get it running from nothing.* *Quick start* first; then *This repository, and its seed*
  for the three roads, *The build environment* for what the commands expect, and *What comes from outside, and
  how it moves* for when the outside moves.
- *Someone who has to maintain it.* *How the tests are written* and the five `tests/*.rs` chapters are the
  contract; *The program's own pipeline* and *This repository* are the machinery around it; *What comes from
  outside, and how it moves* is the update procedure; *The rules* is what must stay true and why.
- *Someone who wants the implementation, as a specification.* Part II in order, from *The package: what a
  declaration is* to *The rules*.
- *A reader that is a program.* *The reader that is not a person* is the argument, *This repository* has the
  road that needs no seed, and *The command line, and what each command is for* plus *The disk, and the log* are
  the two contracts it works against: standard output is data, standard error is the log.
- *Someone deciding whether to use this at all.* *When not to* first, then *Where this differs from WEB* and the
  four claims. The book would rather lose a reader early than have one who resents the cost later.
