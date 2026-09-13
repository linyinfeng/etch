= When not to

Most of the case against literate programming is reasonable, and a document that cannot state it is selling
something. This chapter is the ledger: what the method costs, who it was designed for, and the programs
where the cost is not repaid.

== What it costs

The four claims have four prices, and they are not the same price.

The first is paid in build machinery. The document has to evaluate before anything is produced, so the
document language is a Turing-complete language sitting between the writer and the compiler: a loop that
does not terminate, or a typo in a helper, produces no output at all, and the error the writer sees is a
document error rather than a compiler error. In a repository like this one the price continues past the
document: the tool that reads it has to exist before the first build, which is why this repository carries a
seed branch and a bootstrap — and why the toolchain is a prerequisite rather than something the book can
hand you.

The second is paid by the writer, in attention. The arrangement is not checked by anything. A fragment that
nobody references is a warning; a fragment whose explanation is now false is not even that, because no
compiler reads prose. Holding a web in mind while rearranging it is the work the tool cannot do.

The third is paid by the reader. The order is the author's order, and following a reference is a real cost:
a reader who is jumping between sections is no longer reading. This is why the previous chapters spend so
much on names and on section size — those are the two things that keep the jumps short.

The fourth is paid at every edit. A woven page is a compile away from the truth, and the loop of a
programmer — change a line, run the thing — is not the loop of a writer. Where the page has to be produced
for a reader rather than for the tool, the page is a separate artefact with its own carrier and its own
machinery; this document's is a PDF or an HTML file with the source embedded, and both are code this
repository has to maintain.

There is a fifth cost that is easy to miss because it is not about a claim: the tool is a dependency with a
version, and the version participates in what the document means. This document sidesteps that by shipping
the package inside the binary and resolving it locally, but that is a solution with its own machinery, not
an absence of the problem.

== Who it was for

Knuth said in as many words that he had made a conscious decision not to design a language for everybody —
his goal was a tool for system programmers, not for students or hobbyists. That is not a limitation he
apologised for; it is a scope, and it is worth repeating here because a method that overstates its audience
gets abandoned by everyone in it.

The sharpest sentence against the method is McIlroy's review of Knuth's own book: *"Knuth has shown us here
how to program intelligibly, but not wisely. I buy the discipline. I do not buy the result."* The review is
of one program rather than of the idea, and that is exactly its value: it separates the two, and it points
at the one thing a tool cannot supply. *"Mere use of WEB, though, won't assure the best organization"* —
the method asks for a good arrangement; it does not produce one.

== When it is not worth it

The ledger above is paid off when the *why* is the expensive part: when the reasoning is what a later
reader will need, when the program will be read by people who did not write it, and when the design is a web
of decisions rather than a sequence of steps. It is paid off for programs that live long enough to be
re-read, and for programs whose subject matter is itself hard to explain.

It is not paid off by a program that is read once, by the machine. A script, a migration, a one-off
experiment: the reasoning is not the value and nobody will want it. It is not paid off when the language
already carries the explanation — good names, small functions and tests do a great deal of what prose would
have said, and the more expressive the language, the less the prose adds. And it is not paid off in a team
where one document is written and the code is then edited elsewhere: a single source whose source is not
single is worse than no document at all.

== What it cost here

This repository is one datapoint about the price, and it is worth stating in machinery rather than in prose,
because the machinery is what anyone thinking about doing this will also have to build.

The document is the source, so a fresh clone cannot produce anything: the tree has to be shipped somewhere a
clone can reach, which is why there is a branch whose whole content is one generation — the seed — and a
bootstrap that unpacks it, builds it with whatever toolchain the reader has, and uses that older binary to
tangle the document.

The binary is older by construction, so the document gets tangled twice — once by the seed, once by the result —
and the two are compared. That comparison is a check rather than a build step, and it is what makes "this document
is its own source" testable instead of rhetorical.

The tree has a CI of its own, because it is a program: six named checks, one of which is the round trip — render
the book, read it back out of a PDF and out of a page, compare every file. The repository's CI is a different
job: tangle, refuse drift, publish the generation. Two pipelines for one book, and the split is not a choice:
the tree's checks have to run in the tree, and the tree does not exist until the tangle has run.

And the toolchain is a prerequisite rather than something the book can carry. Everyone who edits it installs
`typst`, a Rust toolchain and a linker, because the repository cannot hold an environment of its own — that would
be a tracked file the document does not produce, which the build chapter takes up.

None of that is objectionable. It is the price of one source being the only source, and it is worth naming
because the alternative — a document that is a *copy* of the code — costs less and is worth less. What it does
mean is that the method is not free for a repository, only for a page.

One argument deserves a second look here, because it gets stronger every year. Reading code has become cheap:
a model, or a colleague with a search tool, can reconstruct a surprising amount of what a program does without
any prose at all. That is a real argument against spending the writer's time on explanation, and it is the
reason the fourth claim of this book is stated as a claim rather than assumed. What it does not remove is what
the ledger above pays for: the reasoning, which no reader can recover from code that does not contain it, and
one source whose drift the build notices. What a machine reader does to that argument is the chapter on the
reader that is not a person.
