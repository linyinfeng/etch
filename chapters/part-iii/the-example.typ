= The example, which is this document

This part is the evidence. The gate comes first — how the tests are written, and the five of them that check
tangling, laziness, the declaration stream, ownership and self-reproduction — then the repository the tree comes
from, the build it is built in, the pipeline that publishes each generation, and what to do when the outside
world moves.

A literate program is worth what its subject is worth. Forty lines can show the syntax — a reference
resolves, indentation survives, a compiler's complaint comes back with a chunk name — and can show none of
the decisions that make the practice worth the trouble: what belongs in one fragment, where the seams go,
what to do when the reference graph is deeper than a reader can hold in mind, and which corner you would
rather cut. A program that small never asks, so it never answers.

The decisions are here instead, because this document is a program rather than a description of one:

- *One source, two outputs.* `lp tangle lp.typ` writes the crate, the package, the control files, and the copy
  of the book itself; `lp weave lp.typ lp.pdf` renders what you are reading.
- *A document that reproduces its own tree*, checked by a test that re-tangles the book and compares it —
  `the_document_regenerates_the_sources_we_are_running`, which is also why the crate's source has to be
  the whole tree.
- *A seed that has to be able to read the next generation*, because a fresh clone has no binary to tangle
  with.
- *Six claims with a name each.* `package`, `test`, `clippy`, `treefmt`, `roundtrip`, `devShell` —
  `nix flake check` is the loud half of every claim this document makes, and it is not a script anyone has
  to remember to run.

Every command a demonstration would have shown you appears in the chapters above, applied to this document:
`lp tangle --check` for drift, `lp map` for which declaration produced a line, `lp explain` for a compiler's
complaint handed back to the chunk that caused it, and the pipeline that published the tree you are reading.
Read front to back, the book is the method, then the design walk, then the evidence for both.
