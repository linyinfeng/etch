= Abstract

This book is a program, and the program is this book. It is literate in Knuth's sense — an essay in which the
code is quoted in the order the argument needs rather than the order a compiler needs — and it is also the
source of `lp`, the tool that tangles it into a Rust crate, a flake, a command line and the tests that check
them. The tree is generated from the argument, so the argument is what gets edited, reviewed and diffed.

Two things make that worth doing now rather than in 1984. The first is that the argument becomes an artifact:
it is the thing that is maintained, and the code is a by-product of keeping it good. There is no second
document to fall out of date, because there is no second document — the only way to change the program is to
change the book. The second is that a machine can now find, read, rewrite, check and update a whole book in
minutes, which is not a thing a person does. The cost that kept literate programming a curiosity for forty
years collapses, and what an agent does not bring is the discipline that making the book the source imposes
from outside.

What this book does not promise is an improvement. Nothing here checks the prose, the order of its argument, or
whether the argument is any good: those cannot be checked by a machine today, so they are not attempted, and
they are the maintainer's responsibility, human or machine. What is offered is a position and its
demonstration — the argument first, the code as its by-product, and a convenient process for turning one into
the other — and one program's evidence that the position is livable.
