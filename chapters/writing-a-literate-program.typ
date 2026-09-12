= Writing a literate program

A literate program is a web of named pieces, and the order they appear in is the order the author found
decisions being made — not the order the machine needs. That is the whole method; the rest of this chapter
is what it costs to follow it.

The first thing to take seriously is that this is a *different* order, not a prettier one. A program written
top-down has to defer everything the author has not decided yet; a program written bottom-up has to invent
names for things the reader has not been told about. Finding the order that a person can follow is the work,
and the tool's only contribution is that the search is free: expanding a reference is text substitution, so
the compiler never has to be persuaded of anything. `<<the recovery>>` can sit in the section that explains
what can go wrong, and the callers can appear later, once the reader knows what they are calling. WEB put it
as a program being a web rather than a tree, and this tool's `<<…>>` is that sentence turned into a
mechanism.

== A section is what a reader takes in at once

Knuth's rule of thumb from reading student programs is a dozen lines of code for one section, and it is a
rule about the reader, not the language: a dozen lines is about what someone can hold while also holding
the prose that introduced them. When a section runs longer than that, the usual fix is not to write
tighter — it is that the section is two ideas, and the reader has been given no place to stop.

Two things help more than a line count. Keep everything about one data structure together, even when a
top-down order would scatter it, because the reader's memory of the structure is what the later sections
spend. And let the boundaries fall where the *explanation* falls, not where the target language's
functions fall: a section is one thing said, and a function is one thing called, and they are not the same
unit. This document breaks that rule where the language forces it — one section per file skeleton, because
a Rust file has to exist — and the seams show.

The three parts of a section, in the order they belong in: the informal explanation, the named pieces it
introduces, and the formal text that uses them. Any part may be empty. A section is small enough to be read
on its own, which is the point of the shape.

== Names

A name should say what the thing is, and the part of speech should say which kind of thing it is: verbs for
procedures, noun phrases for data. `store the word in the dictionary` describes an action and belongs on a
procedure; `procedures for sorting` describes a group and belongs on a list of them. Knuth called this a
kind of truth in naming, and the failure it prevents is concrete — a verb on a data structure, or a noun on
a procedure, is a reader looking for the wrong kind of thing.

A name has to be complete enough to carry its essence and no more. It is a mistake to fold the assumptions
about local and global variables into the name; the assumptions belong in the sentence above the code,
where they can be stated once and read. The convention for spelling the name — case, underscores — belongs
to the target language and nothing else does. This document's names carry their file as a prefix
(`tangle: a chunk as declared`) because a reader of a flat list has no directory to look at.

And the words in the prose are the words in the code. Using two terms for one thing is the cheapest way to
confuse a reader who is already holding a web in mind.

== Prose that is not a play-by-play

A play-by-play account of an algorithm is not documentation: stepping through a loop in sentences is the
code written twice, in a worse notation. What the prose owes the reader is the intuition — why this step
exists, what would break without it, what the invariant is — and the code is right below it to be checked
against. The prose goes first, and it says what the code will do before the code does it; the other order
reads as a caption.

Three small rules that make prose readable in a document that is also a program: pick a person and keep it,
because mixing `it` and `we` in one section makes the reader re-derive who is acting; do not start a
sentence with a symbol; and when a term is introduced, use it for that thing and nothing else. The last one
is not pedantry — the reader has no compiler for prose, and no error message when the two words drift.

== Where the seams go

A fragment must not carry its host's syntax. The closing brace, the `end`, whatever the target language
uses to finish the context, belongs in the section that opens the context, and never in the fragment that
fills it. Mixing the two conventions is not a style difference — it is the kind of mistake that survives
review and then does not compile, and Knuth reports seeing it produce bugs that are hard to attribute.

This document's version of that rule is narrower, because a fragment is spliced into a line of its own: a
fragment contains no blank lines, and no closing `}` of the frame it is spliced into. Both rules exist for
the same reason as the original — the seam has to be in one place, and the reader has to be able to see
where a fragment begins and ends.

Error handling is a seam worth making explicit. A section responsible for the normal path should read as the
normal path; the recovery goes in the section that explains the failure, and the main section names it and
moves on. This is the arrangement that makes the best error handling cheap to write, and it is the one
claim in this chapter that a program keeps even if nobody reads it.

When the subject is a data structure, a picture is often the prose. This document's page is Typst, so a
diagram costs nothing but the decision to draw it, and a verbal explanation of an interleaved array is
usually the longer and worse option.

== Say the whole thing first

The most common way a literate program fails is not a bad sentence, it is a good sentence too late.
McIlroy's review of Knuth's own book makes the point at its sharpest: the central idea of the program he was
reviewing arrives so far in that he had spent the first half misunderstanding its space cost, and his diagnosis
was that Knuth had been documenting on the fly. A reader who has not been told the overall structure will invent
one, and everything after that is read through the invention.

So the shape comes first: what the program is for, what the pieces are, how they fit. It is the one place
where the order is not the order of decisions — it is the order the reader needs before any decision makes
sense. This document's own first chapters are that shape.

== The style is the last thing to arrive

Knuth tore up the first twenty-five pages of one program and started again, and the lesson he drew was that
the style of a literate program is not chosen, it is discovered by writing one badly first. The rules above
are the residue of other people's failures; they are worth knowing before the first draft and worth
re-reading after it. What they cannot do is produce the arrangement for you. A tool guarantees the
mechanism — a reference resolves, a file is written, drift is a failure — and nothing about the arrangement,
which is the whole of the work and the reason a later chapter is about giving up.
