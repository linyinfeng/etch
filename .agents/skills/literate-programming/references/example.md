# Worked example: an RPN calculator

Two files, no framework, and every `lp` mechanism a real program needs. The document
below is the actual source: it was tangled and run on 2026-09-11 with `lp` 0.1.0 and
typst 0.15.1, and the transcript at the end is real output.

## What the document decides

| Decision | Where to look |
| --- | --- |
| Prose before code, in the reader's order | the RPN paragraph: *why* there is no precedence parser at all |
| Use before definition | `evaluate` references `<<apply one token>>` five sections before that chunk is written |
| Nesting carries the layout | `<<apply one token>>` is typed flush left; the reference line's eight spaces indent the expansion |
| One file, several declarations | `#file("src/calc.py", …)` appears twice and the pieces concatenate in document order |
| Roots own the output | `#file` is the only thing that produces files; `lp list` shows the order |
| Prose explains why | the operation *table* instead of an `if`-chain: one place lists the arithmetic |

## The document (`calc.typ`)

````
#import "lit/lp.typ": chunk, file, rule
#show: rule

= An RPN calculator

This program is small, but it still has one decision worth writing down: where does
the order of operations live? In an ordinary expression `2 + 3 * 4` the answer is a
grammar — precedence, parentheses, associativity. Reverse Polish notation moves the
question into the input (`2 3 + 4 *`) and leaves the evaluator with a stack and no
grammar at all.

That is the whole design. Everything below is the consequence of it.

== What the program offers

`evaluate` is the interface: give it tokens in the order they were written, get back
the number. It keeps its state in a local stack, so two calls cannot interfere with
each other — which is what makes it testable without touching the outside world.

The operations are a table rather than a chain of `if`s: one place lists the whole
arithmetic, and adding an operator to the language is adding a line to this table (and
a character to the lexer's pattern, two sections down).

#file("src/calc.py", ```python
"""An RPN calculator: `calc.py "2 3 + 4 *"` prints 20.0."""

import sys

from lexer import tokenize

OPERATIONS = {
    "+": lambda left, right: left + right,
    "-": lambda left, right: left - right,
    "*": lambda left, right: left * right,
    "/": lambda left, right: left / right,
}


def evaluate(tokens):
    stack = []
    for token in tokens:
        <<apply one token>>
    return stack.pop()
```)

== The one tricky step

What "apply one token" means depends on whether the token is a number or an operator,
and the code below is written flush left — no indentation at all. It does not need any:
the reference line above carries eight spaces, and the whole expansion is indented to
match. That is the rule to remember when reading this document: a chunk's body is laid
out where the reference put it, not where the body was typed.

Operators take the two numbers produced before them; anything else has to be a number,
and `float` is where a bad expression finally fails.

#chunk("apply one token", ```python
if token in OPERATIONS:
    right = stack.pop()
    left = stack.pop()
    stack.append(OPERATIONS[token](left, right))
else:
    stack.append(float(token))
```)

== Reading tokens

The input is one string; the evaluator wants a stream. `tokenize` is a generator, so a
long expression never has to be held in memory, and the evaluator can pull one token at
a time without knowing where it came from.

Numbers are matched most permissively (`12`, `3.5`) and operators by the same four
characters the table above names. There is no attempt to reject nonsense here: the
evaluator is the only thing that knows what a valid expression is.

#file("src/lexer.py", ```python
"""Turning an expression into numbers and operators."""

import re

TOKEN = re.compile(r"\d+\.?\d*|[-+*/]")


def tokenize(text):
    for match in TOKEN.finditer(text):
        yield match.group(0)
```)

== Running it

The file introduced two sections ago is finished here. A `#file` declaration can be
repeated: the pieces are concatenated in the order the document reads them, so a file
can be opened where its interface belongs and closed where its behaviour belongs. The
two blank lines this declaration starts with are the ones that separate `main` from
`evaluate` in the finished file.

The command line stays deliberately dumb — this is an example, not a CLI framework. It
prints the usage message on an empty expression and returns a non-zero status, which is
the part scripts depend on.

#file("src/calc.py", ```python


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

In a real project the tests would be roots too — one `#file` per test module, each
explaining the behaviour it pins down. `examples/demo/literate.typ` in this repository
does exactly that, and also shows a fragment referenced from two different files
(`<<crate-preamble>>`), which is the other way sharing shows up in practice.
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
  frag  ⟪apply one token⟫            python
  file  ⟪src/lexer.py⟫               python
  file  ⟪src/calc.py⟫                python

outputs: <src/calc.py>, <src/lexer.py>

$ lp map --out . --file src/calc.py --line 20
chunk ⟪apply one token⟫, line 3 of it
    find it with: rg '#chunk("apply one token")'
```

The tangled file shows what the indentation rule did — the chunk was typed with no
indentation at all:

```python
# src/calc.py, tangled
def evaluate(tokens):
    stack = []
    for token in tokens:
        if token in OPERATIONS:      # ← all of this came from <<apply one token>>,
            right = stack.pop()      #   which is written flush left in the document
            left = stack.pop()
```

## Four things the example teaches that a summary cannot

1. **`--out` has to be repeated.** `lp map`, `lp explain` and `lp unaccounted` default
   to `--out out`; if you tangled with `--out .`, pass `--out .` to them too. The failure
   is `no map knows this file`, and its help line says "known files:" with an empty list.
2. **Anything written *next to* the generated code becomes unaccounted.** Running
   `python3 src/calc.py` created `src/__pycache__/…`, and the next `--check` refused:

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

   Note that the drift report printed nothing while ownership was failing: an empty
   stdout from `--check` is an ownership error, so read stderr. The same pattern appears
   at scale in this repository's `examples/demo/build/.lpignore` (`target/`,
   `Cargo.lock`, woven PDFs).
3. **A repeated `#file` inherits nothing.** The two blank lines that separate `main`
   from `evaluate` in the finished file are written at the start of the *second*
   declaration, not borrowed from the first.
4. **Diagnostic back-translation is for compilers that print `file:line:col:`** —
   `rustc --message-format=short`, gcc, clang — via `lp explain`. Python tracebacks say
   `File "…", line N` and are not parsed yet; for those, `lp map --file … --line N` is
   the language-agnostic path. Adding a Python extractor is a row in a data table, not
   new algorithm (see `src/explain.rs` and ADR D5).
