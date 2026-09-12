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
one step. Nothing in that argument depends on the page being beautiful, or on anyone reading it at all.

Knuth's own accounting is the other half of that argument, and it is about cost rather than quality: the
total time to write and debug a WEB program, he reports, is no greater than for the same program written
conventionally — while the programs are better. The mechanism is not the tool, it is the mode the writing
puts the author in: prose that has to be true cannot be skipped the way a comment can, so the author stays
in the position of explaining the program to somebody, which is the position in which the mistakes get
noticed. That is his report rather than a measurement, and this book's evidence is the same kind — one
program, one author, and the tests it left behind.

What the objections do not cover is the two things this document is built on: the *why*, which was never
in the code, and a single source whose drift is a check failure rather than a matter of discipline. A
stance that cannot state its opposition is not an argument.

== What became of the claims

Forty years of other people trying this is the best evidence there is about which claims carry, and it is
worth knowing before deciding to write one.

*The document is the source* is the claim tools were built on. noweb is the clearest line: the same idea with
five control sequences instead of WEB's twenty-seven, no prettyprinter — because prettyprinting is
language-specific and *most programs are edited at least as often as they are read* — and no assumption about
the target language at all. This book and this tool are on that line: the only thing the tool knows about a
target language is the string in the fence.

*The order belongs to the reader* is the mechanism, and it is exactly what a notebook does not have. A cell
has to run, in order, with everything it needs already defined, so a notebook's order is the runtime's. That
is the boundary between this tradition and Jupyter, Quarto or RMarkdown, and it cuts both ways: a notebook can
show you its result, which a woven page cannot, and it cannot be arranged for the reader, which is the whole
of this method.

*Prose is where the thinking lives* is the claim that got separated from the others in practice. The community
that adopted weaving was data science, and what it adopted was the fourth claim — render something a human
reads — not the third. RMarkdown and nbdev are real literate programming by the letter of the first claim and
not by the spirit of the third: the prose explains the analysis, and the code is still the source.

*The woven page is worth having on its own* is the claim that won, in a shape WEB did not intend. Paper is no
longer the main medium for a program, and the document people actually read is a page on a screen, often one
that a notebook generated. The rendering won; the single source mostly did not.

Why it did not spread further has been catalogued more than once, and the categories are tooling, the person,
and the process. Two of the reasons are hard to argue with. Editors, version control and refactoring tools
absorbed part of what prose was needed for, so the gap the document fills is narrower than it was. And
documentation is written for a future reader who does not exist yet, which means the person paying the cost is
never the person being paid — the same economics that make comments stale everywhere. The lesson a tool should
take from that is not that the method is wrong but that *it has to pay off now*: live sync (a loop the tool
leaves to whatever watcher you keep), a diagnostic that comes back to the declaration, a drift check. A tool
that only pays off later is a tax, and a tax gets uninstalled.

The last decade added a reader that is neither a person nor a compiler, and that is a large enough change to
have a chapter of its own at the end of this part. The short version: it makes an arrangement written for a
reader invisible, unless the document *is* what gets read.

How to write one, how to read one, when not to, and where this tool departs from WEB are the next four
chapters; the tool after them is this argument's longest example.
