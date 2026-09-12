= Reading a literate program

Every rule in the previous chapter is written for a reader, so it is worth saying what a reader is
supposed to do with the page. The short answer is read it front to back, because the order is the author's
order and the prose is doing the work the code cannot. The long answer is that a literate program is read
in two directions at once, and the document has to make both of them possible.

Downward is the order itself: a section sets up something, the next one uses it, and the reference is the
promise that the text exists somewhere. Upward is the way back: a name the reader meets for the first time
is a place to leave the text and find the definition. Both directions have to work, and neither is a
hypertext feature — they are the same document read in two directions, which is why a section has to be
intelligible on its own.

== What the reader must be told

Four facts about this notation are not guessable, so this document states them and any document written
with this tool has to do the same.

A section is three things in a fixed order: the explanation, the pieces it names, and the formal text that
uses them. The formal text is not a summary of the prose; the prose is not a comment on the formal text.
They are one thing, and the reader is meant to check one against the other.

A reference resolves later or earlier, and the reader does not have to care which. In this tool a line that
is exactly `<<name>>` is replaced by every section that declares that name, concatenated in document order,
so a name can be declared in more than one place and the pieces are read as one. A document that needs to
show the notation itself writes `@<<name>>`, which is the same thing with the substitution suppressed.

A reference carries no parameters and no conditionals. The parameter is the surrounding code, and the
alternative is a prose sentence that says which one applies. This is a narrower macro system than most
programmers expect, and it is narrower on purpose: it is the smallest thing that lets the text be
rearranged.

There is no reverse index. A conventional document tells you where a name is used; this one tells you where
it is defined, and answering the other question is a search for the name. The next section is about making
that search cheap — and it is a gap, not a feature, so a writer who knows they will be read this way names
things they can be searched for.

== Reading with the tool

The page is not the only way in. Every declaration is a record in the document's metadata, and the tool
will answer questions about it without the reader having to trust the prose.

`lp list lp.typ` prints the declarations in document order — each one's kind, name and language. That is
the table of contents for the code, and it is derived from the same declaration stream the tangle reads.

The compiler's position is the reader's most common entry point: an error at `src/diag.rs:14:5`. `lp map
--file src/diag.rs --line 14` answers which declaration wrote that line, and prints the search that finds it
in the document — which is what a reader in an editor wants, rather than a page number. `lp explain` does the
same for a whole diagnostic, rewriting the compiler's file-and-line into a name from the document. The map is
written while tangling, so it costs nothing to ask and cannot disagree with the tree.

The opposite direction is `lp map --typ 'diag: a plain error'`, or a plain search for the name. The
document is text, the names are unique, and grep is a legitimate reader's tool — the tool has no index to
be faster than it.

== What a reader should expect

Reading a literate program has failure modes of its own, and a reader who knows them can tell a bad document
from a bad page. A section that reads as a play-by-play of code is the code twice; a section that only
explains and never shows the formal text is a description of a program rather than the program; a name met
without its explanation nearby means the web was arranged for the author's convenience rather than the
reader's.

== When the document is bad

The failure modes above are things a reader can see. This section is about what to do once one is found, because
the reader of a literate program is usually its next author.

A section that narrates its code cannot be read, only skimmed, and the reader's useful question is which part of
it the code cannot supply — that sentence is the one to keep, and the rest is the reader's to delete. A name that
does not say what the thing is costs the reader every time it appears, and it is the one repair that is cheap in
this tool: a search and replace, with the tool's own drift check to confirm nothing else moved. A reference graph
too deep to hold is the failure a reader cannot fix in place, because it is a property of the arrangement rather
than of a section; the answers are in the previous chapter, and they mean moving sections.

The failure a reader cannot repair is prose that is wrong. Nothing checks prose, so a sentence that contradicts
the code below it is invisible until someone reads both, and the reader who notices it is now doing the work the
document was supposed to do. That is the one thing worth reporting rather than fixing quietly: the document is
the source, so prose that lies is a bug in the source, and it is the class of bug no compiler will ever find.

The previous chapter's rule applies here too: the reader can only hold so much. A document that assumes more
is a document whose references have to be followed to be understood, and a reader who is following
references has stopped reading and started assembling.
