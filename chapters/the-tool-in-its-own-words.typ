= The tool, in its own words

This is the whole of `lp`: the program and the package it is written with. There is no second source —
the crate and the package in this repository are the output of tangling this file, and
`lp weave lp.typ lp.pdf` renders what you are reading — which is `typst compile` with the package this
tool unpacks already in scope.

It is a literate program, and that is not a remark about its formatting. The document is where the
thinking lives; the code is quoted into it as the evidence that makes the thinking checkable.

The arrangement is free — a chapter can be moved without moving its code, because nothing here is in
the order a compiler wants — and what is not free is whether it is true. The tests are the gate for
every change, and a document that has stopped reproducing its own tree fails them.

Three mechanical facts for whoever edits this next: a line that is exactly `<<name>>` is a reference,
and `@<<name>>` is how to write one that is not (D17); the prose is Typst rather than Markdown, so
emphasis is *one star*; and a chapter that declares anything imports the package itself, because
`#include` splices content without sharing the includer's scope.
