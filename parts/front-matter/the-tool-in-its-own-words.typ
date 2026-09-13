= The tool, in its own words

This is the whole of `lp`: the program and the package it is written with. There is no second source —
the crate is tangled out of this document, the package is one of the files it declares, and
`lp weave lp.typ lp.pdf` renders what you are reading: `typst compile` with a root that covers the document,
and the book attached to the page it renders.

It is a literate program, and that is not a remark about its formatting. The document is where the
thinking lives; the code is quoted into it as the evidence that makes the thinking checkable.

Three mechanical facts for whoever edits this next: a line that is exactly `<<name>>` is a reference,
and `@<<name>>` is how to write one that is not (D17); the prose is Typst rather than Markdown, so
emphasis is *one star*; and a chapter that declares anything imports the package itself, because
`#include` splices content without sharing the includer's scope.
