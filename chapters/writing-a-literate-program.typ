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

== The notation, in twenty lines

Everything this notation does is visible in one small program: a file, one piece it is made of, and the piece
defined under the sentence that explains it.

````typst
#file("greet.py", ```py
<<the greeting>>

print(greeting)
```)

#chunk("the greeting", ```py
greeting = "hello"
```)
````

Three things are worth noticing, because they are the method in miniature. The reference appears before the
definition, and the tool does not care: the file is assembled at the end, so the text can say what a file is
made of and then explain the pieces one at a time. The paragraph above the second piece is not a comment about
the code — the code is not there yet; that paragraph is where the decision that produced it lives. And the
notation is tiny: a reference is a name in angle brackets on a line of its own, and the two declarations differ
by one word.

What the rest of this chapter adds is the judgement about where the pieces should fall.

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

== Two corrections

The rules are easiest to see in the form Knuth used when he taught them: something a reader would stumble
over, and the same thing after the fix.

The first is narration. A section that says *the loop takes the first element, compares it with the next, swaps
them when the second is smaller, and moves on to the second element as the first* has told the reader a loop, in
words, worse than the loop. What the reader cannot get from the code is why the loop can do what it does, and
that is what the prose owes: *everything to the left of the index is in order, so an element only ever moves
left until it is smaller than its predecessor.* The first version is the code twice; the second is the reason
the code is right.

The second is the name. `stores the word in the dictionary` describes what the code below it does, which is the
same mistake in a smaller place: the part of speech is wrong for a procedure, and the name tells the reader what
the next three lines will be instead of what the section is. `store the word in the dictionary` names the thing
the section does, and a name that reads as an instruction is one a reader can follow from a reference without
coming back to check.

Both corrections are one correction. The prose and the names say what the code cannot; the code says the rest. A
section whose prose restates its code is a section with no prose.

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
confuse a reader who is already holding a web in mind. A name should also carry what a reader cannot infer from
it: a piece that loops unusually, exits early, or jumps somewhere needs that word in its name, and a piece that
does the ordinary thing does not. The page can carry the same distinction typographically — the variable set
differently from the literal, so a reader can tell `n` from `26` at a glance — which is a small thing that costs
nothing and is noticed without being explained.

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

One more, about the data rather than the prose: a declaration says what a value can hold, and it cannot say why
the value exists. That sentence is the writer's, it goes next to the declaration, and it is the one thing a
type system will never grow into.

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

The other half of the same judgement is when a piece deserves a name at all. A reference is worth making when
the name carries something the code below it cannot — a reason, an invariant, a decision — or when the piece is
used in more than one place, or when the caller has to be readable without the detail. It is not worth making
when the piece is one expression whose meaning is its own text: a name there is a second way of saying the same
thing, and the reader pays for both. This is where a literate program and its target language can disagree —
many small language-level abstractions have no narrative content at all — and when they fight, the fragment is
usually the one that gives way. A section may be half a function, or three of them.

== How deep a web can be

A reference is free for the tool and expensive for the reader, and the cost compounds: a section that needs three
references to be understood, each of which needs two more, is a document nobody reads the way it was written.
Nothing in the tool notices this — the references resolve, the tree is correct, every check passes — so it stays
the writer's problem, and it has three answers that work.

Order the sections so the graph is shallow where it matters: a name everything references belongs early, and a
name only one section needs belongs in that section. Name the far-away thing in a sentence, because a reader who
is told what a reference is does not have to leave to find out. And when the shape really is a graph rather than
a line, draw the graph — a page saying which five things exist and how they point at each other is cheaper than
any arrangement of the same material in prose. What does not work is pretending the depth is not there, which is
what a document written in the author's order and never re-read looks like.

== Say the whole thing first

The most common way a literate program fails is not a bad sentence, it is a good sentence too late.
McIlroy's review of Knuth's own book makes the point at its sharpest: the central idea of the program he was
reviewing arrives so far in that he had spent the first half misunderstanding its space cost, and his diagnosis
was that Knuth had been documenting on the fly. A reader who has not been told the overall structure will invent
one, and everything after that is read through the invention.

So the shape comes first: what the program is for, what the pieces are, how they fit. It is the one place
where the order is not the order of decisions — it is the order the reader needs before any decision makes
sense. This document's own first chapters are that shape.

== How to start, and how to revise

The shape comes first, and the shape is cheap to change afterwards, which is what makes starting easier than it
looks. A first pass worth writing is this: the file skeletons — every output file, as the sections it will be
made of — then one section at a time, in whatever order the thinking arrives, tangling as you go so the tree
stays buildable and the drift check stays useful.

The order the sections get *written* in does not matter, and that is the one thing this method buys that a
conventional file cannot. What matters is the order they end up in, which is a different question and one that
can only be answered once most of them exist. So the first arrangement will be wrong. That is not a failure of
the method; it is the method: rearranging is a text move with no consequence for the output, which means the
arrangement can be fixed once the reader's path is finally visible.

This book is the evidence for that, in a way it can be held to. It was one file, and it has been rearranged
twice — once into a reading order, once into the thirty-five chapters you are reading. Each time, the measure of
the rearrangement was that the generated tree came out unchanged: a chunk may move anywhere in the text without
moving a byte of what it produces — the pieces of one repeated name have to keep their relative order, and
nothing else does — because the output is assembled from the declarations rather than read where it sits. A
writer without that property could not afford to reorganise a book. A writer with it gets a second and
third chance at the arrangement, which is where most of the quality actually lives — and, as the tool's own
history shows, a rearrangement is also a good way to find the places where the prose had stopped being true.

== The style is the last thing to arrive

Knuth tore up the first twenty-five pages of one program and started again, and the lesson he drew was that
the style of a literate program is not chosen, it is discovered by writing one badly first. The rules above
are the residue of other people's failures; they are worth knowing before the first draft and worth
re-reading after it. What they cannot do is produce the arrangement for you. A tool guarantees the
mechanism — a reference resolves, a file is written, drift is a failure — and nothing about the arrangement,
which is the whole of the work and the reason a later chapter is about giving up.
