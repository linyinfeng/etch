#import "../../package/lib.typ": chunk, file

= A small one, to read in one sitting

The rest of this book is a hard example: ten thousand lines, self-hosting, bootstrapped from a frozen seed.
A reader who wants to see the shape of a literate program before all that should have a small one, and this
chapter is it — a program of about forty lines, written twice, once as a book and once as the shell script it
becomes.

It is declared *here*, in this book, rather than kept beside it, so that the demo cannot drift from the method
it demonstrates: tangling the book produces the demo, and a test tangles the demo's own document, runs what
comes out of it, and compares the bytes.

Three of the demo's lines are written with `@<<…>>` rather than `<<…>>`. That is this book's escape, and this
chapter is the case it exists for: a document that *contains* another document is still tangled by this one, so
the demo's references have to survive the book's tangle and be left for the demo's own.

#file("examples/demo/literate.typ", ````typst
#import "../../package/lib.typ": chunk, file, show-rule, tangle-options

#show: show-rule

= A greeting, in two files

One preamble, two files, and one message that is written below the file that uses it.

#file("lib.sh", ```sh
#!/bin/sh
@<<the preamble>>

greet() {
  printf '%s\n' "$1"
}
```)

#file("greet.sh", ```sh
#!/bin/sh
@<<the preamble>>
. "$(dirname "$0")/lib.sh"

@<<the message>>
```)

= The preamble, and the message

Both files need the same four lines, and this is where they are written — below the files that use them, which
is the whole point of the exercise: the order here is the order of an explanation, not the order `sh` needs.

#chunk("the preamble", ```sh
set -eu
: "${NAME:=world}"
```)

The message is a fragment like the preamble, and `greet.sh` uses it as a whole line, because a reference is a
whole line and nothing smaller:

#chunk("the message", ```sh
greet "hello, $NAME"
```)
````)

#file("examples/demo/run.sh", ````sh
#!/bin/sh
set -eu

lp=${LP:-lp}
"$lp" tangle literate.typ --out build
NAME=${NAME:-world} sh build/greet.sh > build/out.txt
diff build/out.txt expected.txt
echo "the demo agrees with itself"
````)

#file("examples/demo/expected.txt", ````text
hello, world
````)

== What this little program shows

It shows three things, and they are the ones a toy usually skips.

The document names its files and the caller names the directory: `lib.sh` and `greet.sh` are the document's,
`build/` is the runner's, and nothing in the document knows where it will be tangled. That is the same split
the tool keeps everywhere else — the output directory is a command-line decision, the names inside it are the
document's — and it is why the demo's `run.sh` is a runner rather than part of the program.

*One fragment, two files.* `the preamble` is written once and referenced twice, and neither file contains it
twice: `lib.sh` receives the four lines in place of the reference, and so does `greet.sh`. A fragment is a
source of text, not a place in a file — which is what makes a shared preamble possible without a second copy of
it to keep in step.

*Defined after it is used.* Both `the preamble` and `the message` appear in a section *below* the files that
call them. That is the second claim in its smallest form: names are resolved while tangling rather than while
reading, so the document can be ordered for the reader instead of for the shell.

*The escape, because a document contains one.* The book's tangle is what writes `examples/demo/literate.typ`
into the tree, and it would be only too happy to expand the demo's references while it does — so the demo's own
document is written here with `@<<…>>`, and the demo's tangle is the one that fills them in. It is the smallest
case of a real problem: text about text has to say which pass is allowed to read it.

== What it cannot show

The decisions that need pressure: where the seams go when the reference graph is deeper than a reader can hold
in mind; what to do when two generations disagree; what ownership of an output directory feels like when other
tools write there too; which corner you would rather cut and what that costs. A program this small never asks,
so it never answers — *The example, which is this document* is where those are asked, and the rest of this part
is the method that makes them worth answering.

To run it: `sh examples/demo/run.sh` from the root of the tree, or tangle `examples/demo/literate.typ` into
whatever directory you like. The demo's own `build/` is named in the book's `.lpignore`, so running it does not
make the tree's own check complain about files nothing accounts for.
