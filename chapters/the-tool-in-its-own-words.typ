= The tool, in its own words

This is the whole of `lp`: the program and the package it is written with. There is no second source —
the crate and the package in this repository are the output of tangling this file, and
`lp weave lp.typ lp.pdf` renders what you are reading — which is `typst compile` with the package this
tool unpacks already in scope.

It is a literate program, and that is not a remark about its formatting. The document is where the
thinking lives; the code is quoted into it as the evidence that makes the thinking checkable.

The book has three parts, and they are three ways of asking the same question. *Writing a literate
program* is the method: what the four claims cost, how a program is arranged when the reader decides the
order, how to read what someone else wrote that way, when it is not worth it, and what changes when the reader
is not a person. *The tool* is the
design walk: what a declaration is, what a pass does with it, how the result is read back, and why each
of those choices is the one it is. *This repository* is the evidence: the tests, the build, the seed,
and the two lock files the document carries verbatim.

The arrangement is free — a chapter can be moved without moving its code, because nothing here is in
the order a compiler wants — and what is not free is whether it is true. The tests are the gate for
every change, and a document that has stopped reproducing its own tree fails them.

Three mechanical facts for whoever edits this next: a line that is exactly `<<name>>` is a reference,
and `@<<name>>` is how to write one that is not (D17); the prose is Typst rather than Markdown, so
emphasis is *one star*; and a chapter that declares anything imports the package itself, because
`#include` splices content without sharing the includer's scope.
