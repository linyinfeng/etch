#import "lit.typ": lit
#show: lit

= Hello, literate

This whole file is a valid Typst document that also happens to be the source of
a Python program. `typst compile hello.typ` renders this page; `tangle.py`
extracts `out/hello.py` from the same file.

== The program

`<hello.py>` is a *root chunk*: its label looks like a file name, so tangling
writes it to disk. Everything it pulls in is a named sub-chunk.

```py
#!/usr/bin/env python3
<<imports>>

def main():
    <<greeting>>
    <<body>>

if __name__ == "__main__":
    main()
``` <hello.py>

== Imports

Nothing fancy; prose first, so the reader sees why a module is needed.

```py
import sys
``` <imports>

== The greeting

```py
print("hello, literate")
``` <greeting>

== The body

The body is split in two chunks on purpose: both blocks share the label
`<body>`, and tangling concatenates same-labelled chunks in document order, the
way noweb and org-babel `:noweb-ref` do. The first half:

```py
print("chunk order follows the document, not the file")
``` <body>

and the second half:

```py
print("tangled from", __file__.rsplit("/", 1)[-1])
print("running under", sys.implementation.name)
``` <body>

== Notes

This paragraph is plain Typst and never reaches the generated file. Raw blocks
written without a label are untouched by both the weaver and the tangler:

```text
not a chunk
```
