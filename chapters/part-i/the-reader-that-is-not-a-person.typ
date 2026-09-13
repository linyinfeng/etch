= The reader that is not a person

Knuth addressed the program to human beings rather than to a computer, and for forty years the two readers
were distinct: a compiler read the tree, and a person read the page. There is now a third, and it is neither.
It reads the whole tree without getting tired, it prefers the prose to the code, and it is on its way to being
the most frequent reader a program has. That is a larger change to this method than any of the objections in
the previous chapters, and it cuts both ways.

== What it is good at, and what it cannot do

The good half is what the method was already for. A generated document is context in the form a model handles
best — coherent natural language with the code embedded where it is being explained — and nothing in it is
unexplained, which is exactly the property a reader with no history needs. A web of named pieces is also the
shape of retrieval: a top-level intent, and the details under the names it points at. The instructions in the
chapter on writing one are, without having been written for this, instructions for a good machine reader too:
name the thing as what it is, say what the code cannot say, put the whole structure first.

The half that has not changed is the important one. A model can produce a fluent explanation of any code, and
nothing checks it: prose has no compiler, and a wrong explanation that reads well is the most expensive kind of
wrong there is. What a model cannot derive is the *why* — why this shape and not the obvious one, what was
tried and rejected, which invariant everything else depends on. That was never in the code, and no amount of
reading recovers it.

== The arrangement is invisible to it, unless the document is what it reads

The method's central claim is that the order belongs to the reader. A machine reader gets the order the
compiler needs, because that is the order of the tree: the arrangement — the thing this book spends its first
half arguing about — does not exist in what the model reads by default.

That turns the first claim from a convenience into the load-bearing one. If the document is the only source,
then the reader that reads the source reads the arrangement, and the names in it are an index it can search
rather than a decoration. If the document is a second copy beside the code, the reader reads the code's order,
and the prose is a commentary it may or may not fetch.

== Why agents make the old problem worse, and the old answer better

The historical failure of this method was drift: two copies, and a person who is supposed to remember to keep
them in step. An agent makes that failure faster and more certain, because editing the code is exactly what it
is good at, and it has no reason to look at a document that is not the source.

The same agent makes the answer better. One source, edits only there, and a check that fails when the two
disagree turns "please keep the document up to date" — an instruction no agent and no person reliably follows —
into a build error. That is what this repository does, and it does it in the strongest available form: the
program in this book is generated from the book, so an edit to the generated tree is caught by the same
machinery that catches everything else. The discipline is no longer a promise; it is a check.

== What this changes for a writer

Two of the rules change weight, and one new one appears.

The dozen-line section was calibrated to human working memory, and a machine reader has no such limit. What
it has instead is a retrieval problem: which pieces matter for the question in hand. So the rules that
matter more now are the ones about names and about the shape: a name is a search key, and a shallow graph is a
retrieval structure. A fragment can be longer than a dozen lines if it is one thing said; it cannot be named
badly.

The new rule is about what prose is for. An explanation that restates the code — what it does, in sentences, in
order — is now nearly free to produce and nearly worthless to read, because whoever needs it can have it on
demand. The prose that is worth writing is the part a reader cannot reconstruct: the reason, the rejected
alternative, the invariant, the thing that was surprising. Written this way the document is not documentation;
it is the part of the program that was never in the code.

== Where this is already happening

The idea is in the air, and it is worth knowing that the pieces exist. There is an environment built for
exactly this reader, which treats names as first-class objects so that a model can search them the way an
editor searches symbols; there are skills that turn an existing codebase *into* a literate program, which is
the reverse direction and an interesting admission that the document is worth having after the fact; and there
is a project whose slogan is that humans should write the prose while the model writes the code. What is not
in the air is the stance: the document as the *only* source, the generated tree as something no one edits, and
drift as a check that fails. That is the difference between using prose to help a model and using it to
constrain one.

The honest counterargument is the one from the previous chapter, and it gets stronger every year: if an
explanation can be reconstructed on demand, a team can rationally decide that writing one is not worth anyone's
time. The answer is not that reconstruction is bad — it is usually good enough — but that it is unchecked. A
document that is the source is checked: the tree either matches it or the build says it does not. What a reader
does with an unchecked explanation is a question this method does not have to answer, because it does not
produce one.

The tool in the next part is built under exactly that constraint, and the constraint is why the tool is the
example: it is a program whose only source is the book that describes it.

One road through the repository chapter is where that stops being a claim and becomes something a reader can
do: it needs no seed and no network, because a reader that is a program can install the package out of the
markup, ask the document for its declarations, expand them by the rules this book states, and end up with the
tree the document describes — graded, by the tool that tree builds, on whether every file comes back `ok`.
The arrangement is what makes that possible: the names, the fences and the references are all in one place,
and the code the reader needs to agree with is the code that reader just rebuilt.
