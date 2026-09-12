= What literate programming is, in four claims

The idea splits into four claims, and they are worth separating because a reader can accept some of them
without the others. Each one can be argued for, paid for, and given up on its own.

1. *The document is the source.* The code is tangled out of it, so there is no second copy that can
  disagree with the prose.
2. *The order belongs to the reader.* Names are resolved while tangling, not while reading, so the text
  can be arranged in the order the design is understood rather than the order the machine runs it.
3. *A program is written as literature.* Prose is not a comment on the code; it is where the thinking
  lives, and the code is the evidence that the thinking is real.
4. *The woven document is worth having on its own.* Here that is `lp weave lp.typ lp.pdf`: the same
  declarations, rendered as the page you are reading.

This document takes the first claim literally and argues for the other three by being an example of them.
The case against all four is worth stating at its strongest, because most of it is reasonable. The payoff
falls as a language gets more expressive: good names, small functions and tests already carry much of what
prose would say. The friction has a history — an extra tool between the author and the compiler, no editor
support, diagnostics pointing at generated code — and it is why WEB and CWEB stayed niche. And reading
code just got cheap, which is an argument about the work rather than about the tool.

The argument that survives all of that is the one worth starting from, because it does not depend on
anyone reading the woven page. It is about the second claim, and it says that a literate program is a
different program: the arrangement is not a report about the code, it changes what is cheap to write, and
what is cheap to write is what gets written well. In a conventional file, a procedure that updates a data
structure has to write its error recovery inline, and the recovery then looks like the bulk of the
procedure. The observation Knuth draws from teaching WEB is that an author avoids that — error handling
gets written as little and as late as the language allows, because the main step should not look like an
error path. In a literate program that step can name its recovery and move on — `<<check the data>>` — and
the best recovery the author can write goes where a reader will find it while the section still reads as
one step. Nothing in that argument depends on the page being beautiful, or on
anyone reading it at all.

What the objections do not cover is the two things this document is built on: the *why*, which was never
in the code, and a single source whose drift is a check failure rather than a matter of discipline. A
stance that cannot state its opposition is not an argument.

How to write one, how to read one, and when not to are the next three chapters; the tool after them is
this argument's longest example.
