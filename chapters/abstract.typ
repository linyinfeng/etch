= Abstract

`lp` is a literate programming tool for Typst documents. One document is both the book and the only source of
the program it describes: it declares fragments of code and the files they make up, and `lp tangle` expands
those declarations into a working source tree. This document is that kind of document. The tool it describes
is the tool that generated the tree you are reading it in, and every claim it makes about itself is checkable
in that tree — the tests fail when the document stops reproducing its own sources.

The method is old and the audience is not. Knuth wrote literate programs for a person; a growing share of the
readers of a source tree now are programs themselves, and a program reads the tree rather than the book. An
arrangement that exists only in prose is invisible to it. What changes with them is not only who reads: a
whole book that a person cannot afford to keep coherent is something an agent can find, read, rewrite and
check in minutes. The code here is a by-product of keeping the argument good, and the argument is what is
maintained.

The book is written for five readers in particular: someone who wants to write a literate program, someone who
wants to use this tool, someone who has to get it running from nothing, someone who has to maintain it, and
someone who wants to read a working specification of it. Two more are welcome — a reader that is a program,
and a reader who is deciding whether the method is worth it at all. The chapter after this one says which
chapters are theirs.
