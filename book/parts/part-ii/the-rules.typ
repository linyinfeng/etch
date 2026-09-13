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
- *Generated files stay out of git*, and the only thing edited is the book: its chapters, and the crate,
  package and control files they declare. The seed is output too, and lives on the `tangled` branch for
  bootstrap reasons — a fresh clone has no binary to tangle with. It is the same guarded tree, one
  generation behind.
- *An error points at a declaration*, never at a bare string: which chunk, and which
  line inside it.
- *Unexplained files are errors, deletion is explicit.* Everything under the output
  directory is produced by a declaration or listed in a `.etchignore`; nothing unexplained is ever
  deleted for you.
- *Only changed bytes are written, and a document that does not evaluate is not tangled.*
  The previous good output stays until the document is valid again.
- *No watcher.* The tool does know which files a pass reads — it asks Typst, which is the same answer the book
  is built from — but knowing the set is not the same as being a watcher: a watcher is a second loop inside
  this program, with its own idea of when a file changed and its own ways to be wrong about a half-written one.
  The first version of that loop watched itself and ran a pass every two hundred milliseconds, forever; the
  second borrowed git's view of the tree and was right more often, which is not the same as right. So the loop
  belongs to somebody else's tool: `watchexec -e typ -r -- etch tangle etch.typ` is the whole of what this one
  would have done. What the tool owes
  that arrangement it already has: a pass writes only changed bytes, and a document that does not evaluate
  leaves the last good output in place, so re-running the command blindly costs the run and nothing else.
- *A read is not an edit, and what the tool writes is not a reason to run again.* These two are why the watcher
  above was hopeless and worth stating anyway, because anything that does decide to run a pass has to keep them
  apart: this tool reads its own inputs on every pass, and it writes its own output on the way.
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
  why. `typst` is a hard dependency of tangling (`ETCH_TYPST`, then `PATH`).
