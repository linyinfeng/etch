= The rules

These are not style preferences; each one was paid for.

- *Elegance is an admission requirement.* If the only way to build a feature is to
  search source text heuristically, or to parse Typst a second time, the feature is not
  built. That is how line-number mapping, label-as-chunk-name and static analysis of
  Typst were dropped.
- *The tool never parses Typst.* Its whole understanding is one `typst eval` reading the
  declaration stream.
- *No line numbers.* Typst's script layer has no source positions; provenance is
  chunk-level, and pretending otherwise would mean re-parsing.
- *Orthogonality.* No knowledge of any target language in the algorithms; language
  differences are data (the fence tag), never code.
- *Generated files stay out of git*, and only this document is edited: the crate, the package,
  the control files. The seed is output too, and lives on the `tangled` branch for
  bootstrap reasons — a fresh clone has no binary to tangle with. It is the same guarded tree, one
  generation behind.
- *An error points at a declaration*, never at a bare string: which chunk, and which
  line inside it.
- *Unexplained files are errors, deletion is explicit.* Everything under the output
  directory is produced by a declaration or listed in a `.lpignore`; `lp` never deletes
  anything by itself.
- *Only changed bytes are written, and a document that does not evaluate is not tangled.*
  The previous good output stays until the document is valid again.
- *The order is free and the language tag is data* (D18). Thought-first, progressive
  disclosure and logical consistency cannot be checked by a tool, so they are the
  writer's job: this book argues for them, and no check can do it instead.
- *The code carries no comments.* An explanation belongs in the prose that introduces the
  chunk — where it can be read in order, argued with, and moved when the design moves — and a
  comment is a second voice saying the same thing in a place a reader of this book never looks.
  This document is its own example: nothing it tangles has a comment in it, and the sentences that
  used to be comments are one paragraph up, in the chapter that introduces the code. The one
  banner that survives is `Cargo.lock`'s, and that one is cargo's — the document quotes the lock
  verbatim, so what cargo writes is what the document has to carry.
- *Dependencies are chosen from mature crates* (D7); every new one gets a line saying
  why. `typst` is a hard dependency of tangling (`LP_TYPST`, then `PATH`).
