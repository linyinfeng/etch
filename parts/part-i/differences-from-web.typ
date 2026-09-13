= Where this differs from WEB

This book is a literate program in the tradition WEB started, and it departs from WEB in eight places
worth naming. The point of naming them is that a reader who finds a difference cannot tell a decision
from an oversight, and two of these are oversights — gaps this tool has not closed, not features it
declined.

== A name may be declared more than once, silently

WEB writes `+=` on the second definition of a name, so the reader is told at the definition that the
pieces are one thing. Here the pieces of a name are concatenated in document order with no marker at
all: a repeated name is a concatenation, and the notation has no signal at the point where the signal
would help. The mechanism is the same one WEB has; the marker is what was dropped, and that is the first
of the two gaps: an accidental reuse reads as a deliberate one.

== There is no reverse index

WEB prints `This code is used in section N` next to every definition and a `See also` list of the places
a name is used. That is the reader's upward direction, generated. This tool cannot generate it: Typst's
script layer has no source positions, so the pass knows which declaration produced a line of a generated
file but not where a reference sits in the document (D14). The reader's substitute is a search for the
name, and `lp map` answers the same question from the compiled side. This one is a gap. A document
written for this tool has to be arranged so that jumping is rare, because jumping is all there is.

== There are no change files

WEB keeps the base document intact and applies system-specific changes from a separate change file,
matched against the base by content. That was a portability mechanism for a world of incompatible
compilers. Today the same problem is solved a level down — conditional compilation, or a branch — and
this repository's answer is that the tree is a plain, buildable program with its own package manager and
its own CI. A change file would be a second language for describing edits, and nothing here needs one.

== The tangled output is not made ugly

Bentley's introduction to WEB records the intention: the tangled output should be as ugly as possible, so
that programmers deal with the WEB file and not with the generated source. This repository wants the
opposite. The tangled program is the thing that is built, tested, cached and shipped, it carries its own
tooling, and it has to be byte-comparable with a seed generation (`--check`, and the `roundtrip` check in
the generated tree's own flake). So the output is honest source, and the mechanism that keeps the writer
in the document is not ugliness but the fact that the document is where the change has to be made: editing
the tree fails the drift check.

== Positions are not injected into the output

WEB can point a compiler's diagnostic at the WEB file because processing happens when the compiler runs,
and a section number is a legitimate line directive. Here the generated file has to stay exactly what a
compiler reading that language expects — see the previous paragraph — so provenance is read back instead
of baked in: the pass records which declaration wrote each line, and `lp map` and `lp explain` translate
the compiler's position into a name afterwards.

== The declaration stream is read by evaluating, not parsing

WEB defines its own notation and processes it. This tool refuses to parse Typst, because Typst is
Turing-complete: a declaration can come from a loop, a branch or an included file, and any parser would be
wrong exactly where the document is clever. The authority is evaluation, so the tool asks Typst a question
and reads the answer. The price is that the document has to evaluate, and that Typst is a hard dependency
of tangling.

== The highlighting is not the tool's

WEB knows the language it is weaving, so its weave can set keywords, comments and section numbers by itself. This
tool knows the string in the fence and nothing else — that is the orthogonality rule the rules chapter states — so
whatever a page does with a code block, it does by handing that string to the typesetter. The tool's own
contribution is a monospace block whose text is exactly what will be written to the file, and the benefit of that
is not only simplicity: a reader can copy a line out of the page and have it be the line, which is not true of a
program that has been typeset into something prettier than its source.

== One more: a reference takes no parameters

This one is smaller but felt in every fragment. A reference here takes no parameters, where WEB's macros take at
most one, and the parameter is the code around the reference — the conditional case is a sentence in the prose
that says which version applies. It is the narrowest macro system that still lets the text be rearranged, which
is the only thing it is for.
