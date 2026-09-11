# Worked example: an RPN calculator

Two files, no framework, and an exposition you can check. The first paragraph is the design
decision — why reverse Polish notation makes the grammar disappear — and everything after it
exists to make that decision inspectable: the code is what the decision looks like when it has
to run. The roots are skeletons that name their parts, and each part is explained in its own
section (skeleton-first is one of the two legitimate shapes; pieces-first, assembly-last would do
just as well). The document below is the actual source; it was tangled and run on 2026-09-11 with
`lp` 0.1.0 and typst 0.15.1. The transcript at the end is real output.

## What the document decides

| Decision | Where to look |
| --- | --- |
| Idea before shape before detail | the RPN paragraph explains why there is no precedence parser; then the whole file appears |
| Every root is a skeleton | `src/calc.py` names `<<imports>>`, `<<the operation table>>`, `<<the evaluation loop>>`, `<<the command line>>` |
| Depth is two levels here | the skeleton names `<<the evaluation loop>>`, which names `<<apply one token>>` |
| Each name is explained where it is used | the loop is explained as stack policy; the one token step is explained with the indentation rule |
| Prose keeps the promise | the table-versus-`if`-chain paragraph is the reason the table exists; nothing else claims to be |
| A file can be declared twice | not used here — `examples/demo/literate.typ` in the repository shows it |

## The document (`calc.typ`)

````
#import "lit/lp.typ": chunk, file, rule
#show: rule

= An RPN calculator

This document is an argument, read from the front. It starts with the shape of the
program and gets more specific as it goes: the first section is the whole file with
nothing filled in, and every name in it is explained by a later section. A reader who
stops after the first section still knows what the program is.

The program is a reverse Polish calculator. That choice is worth one paragraph, because
it is where all the difficulty went: in `2 + 3 * 4` the order of operations lives in a
grammar — precedence, parentheses, associativity. In `2 3 + 4 *` it lives in the input,
and the evaluator is left with a stack and no grammar at all.

== The shape of the program

The file, before any of it is explained:

#file("src/calc.py", ```python
"""An RPN calculator: `calc.py "2 3 + 4 *"` prints 20.0."""

<<imports>>

<<the operation table>>


def evaluate(tokens):
    <<the evaluation loop>>
<<the command line>>
```)

`evaluate` is the interface: tokens in the order they were written, a number out. It
keeps its state in a local stack, so two calls cannot interfere with each other — which
is what makes it testable without touching the outside world.

== What the program needs from outside

Two things. `exit`, because a command line has to be able to say no with a status code.
And `tokenize`, which is the other file in this program, defined in the next section —
`calc.py` never parses text, and `lexer.py` never knows what the tokens mean.

#chunk("imports", ```python
import sys

from lexer import tokenize
```)

== Reading the input

The evaluator wants a stream of tokens; the user has one string. `tokenize` is a
generator, so the string is never split into a list that nobody needs, and the evaluator
can pull one token at a time without knowing where it came from.

The pattern is deliberately permissive — it recognises numbers and the four operator
characters and nothing else. Deciding what a valid *expression* is belongs to the
evaluator, not here; a lexer that tried to do it too would have to know about the stack.

#file("src/lexer.py", ```python
"""Turning an expression into numbers and operators."""

import re

<<what a token looks like>>


def tokenize(text):
    for match in TOKEN.finditer(text):
        yield match.group(0)
```)

#chunk("what a token looks like", ```python
TOKEN = re.compile(r"\d+\.?\d*|[-+*/]")
```)

== The arithmetic, in one place

Four operations, one table. A chain of `if`s would work and put the arithmetic in the
middle of the evaluation logic; the table keeps the whole of it visible on one screen,
and adding an operator is a line here plus a character in the pattern above — two places
that a reader can check against each other.

#chunk("the operation table", ```python
OPERATIONS = {
    "+": lambda left, right: left + right,
    "-": lambda left, right: left - right,
    "*": lambda left, right: left * right,
    "/": lambda left, right: left / right,
}
```)

== Running the loop

Evaluation is a stack machine: numbers accumulate, operators consume. The loop below is
the whole of that policy — it names one step, and the next section explains what the step
does. Nothing about the step is needed to read this.

The body of the loop arrives in the next section; because the reference below is indented
by four spaces, and it is itself pulled into an indented place, the expansion ends up
eight spaces in. Indentation is relative to the reference that pulled the text in, at
every level.

#chunk("the evaluation loop", ```python
stack = []
for token in tokens:
    <<apply one token>>
return stack.pop()
```)

== Applying one token

An operator consumes the two numbers produced before it; a number is pushed. Note where
this code ends up: the reference that pulls it in is indented by four spaces, so the loop
body is indented, even though the chunk below is written flush left. The chunk's own
layout is the layout of the text you are reading; the indentation comes from the place
that names it.

`float` is where a bad expression finally fails, and the traceback will point at this
chunk.

#chunk("apply one token", ```python
if token in OPERATIONS:
    right = stack.pop()
    left = stack.pop()
    stack.append(OPERATIONS[token](left, right))
else:
    stack.append(float(token))
```)

== The command line

The tail of `calc.py`, written as one chunk about running the program rather than about
evaluating expressions. It starts with two blank lines on purpose: in the finished file
they are the ones that separate `main` from `evaluate`, and nothing is inherited from the
first declaration of the file.

The exit status is the part scripts depend on: an empty expression gets a usage message
and a non-zero status, everything else prints the result.

#chunk("the command line", ```python


def main(argv):
    expression = " ".join(argv[1:])
    if not expression.strip():
        print("usage: calc.py <expression>")
        return 2
    print(evaluate(tokenize(expression)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```)

== Checking it

Two files, and the only way to know the argument is true is to run it:

```sh
$ lp tangle calc.typ --out . && python3 src/calc.py "2 3 + 4 *"
20.0
```

In a real project the tests would be roots too, one `#file` per test module, each sitting
next to the behaviour it pins down. `examples/demo/literate.typ` in this repository does
that, and also shows a fragment shared by two different files (`<<crate-preamble>>`).
````

## Transcript

```sh
$ lp tangle calc.typ --out .
wrote  src/calc.py  (37 lines, python)
wrote  src/lexer.py  (10 lines, python)

$ python3 src/calc.py '2 3 + 4 *'
20.0

$ lp list calc.typ
calc.typ
  file  ⟪src/calc.py⟫                python
  frag  ⟪imports⟫                    python
  file  ⟪src/lexer.py⟫               python
  frag  ⟪what a token looks like⟫    python
  frag  ⟪the operation table⟫        python
  frag  ⟪the evaluation loop⟫        python
  frag  ⟪apply one token⟫            python
  frag  ⟪the command line⟫           python

outputs: <src/calc.py>, <src/lexer.py>

$ lp map --out . --file src/calc.py --line 19
chunk ⟪apply one token⟫, line 2 of it
    find it with: rg '#chunk("apply one token")'
```

`lp list` is the document's reading order, and it is also the order the tool checks: every
`frag` above appears after the place that first refers to it.

The generated file shows what the indentation rule did. `<<apply one token>>` is written flush
left in the document and pulled in by a reference that is itself four spaces in:

```python
# src/calc.py, tangled
def evaluate(tokens):
    stack = []
    for token in tokens:
        if token in OPERATIONS:      # ← from <<apply one token>>, written flush left
            right = stack.pop()
            left = stack.pop()
            stack.append(OPERATIONS[token](left, right))
```

## Three things the transcript teaches

1. **Anything written next to the generated code becomes unaccounted.** Running the program
   created `src/__pycache__/…`, and the next `--check` refused:

   ```sh
   $ lp tangle calc.typ --out . --check
     × nothing accounts for these files:
     │   src/__pycache__/lexer.cpython-314.pyc
     help: declare each one in the .lpignore of its directory, or delete it with `lp unaccounted --delete`

   $ printf '/calc.typ\n/lit\n/src/__pycache__\n' > .lpignore   # matching means *protect*
   $ lp tangle calc.typ --out . --check
   ok     src/calc.py
   ok     src/lexer.py
   ```

   While ownership was failing, the drift report printed nothing: an empty stdout from `--check`
   means an ownership error, so read stderr. `examples/demo/build/.lpignore` in the repository is
   the same pattern at a larger scale (`target/`, `Cargo.lock`, woven PDFs).
2. **`--out` has to be repeated.** `lp map`, `lp explain` and `lp unaccounted` default to
   `--out out`; a document tangled with `--out .` fails there with `no map knows this file`.
3. **Diagnostic back-translation covers compilers that print `file:line:col:`** — `rustc
   --message-format=short`, gcc, clang — through `lp explain`. Python tracebacks say
   `File "…", line N` and are not parsed yet; for those, `lp map --file … --line N` is the
   language-agnostic path. Adding a Python extractor is a row in a data table, not new algorithm
   (see `src/explain.rs`).
