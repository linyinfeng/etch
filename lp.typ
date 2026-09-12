#import "@local/lp:0.1.0": chunk, file, show-rule, tangle-options
#show: show-rule

// Where the tangled tree keeps this book, so that a tree can be read — and re-tangled — without the
// repository it came from. The tree's own `.gitignore` travels with it: the book is the whole of what
// this repository was before tangling, not only its prose.
#tangle-options((
  book-directory: "book",
  book-files: (
    "lp.typ",
    "README.md",
    ".gitignore",
    "chapters/the-tool-in-its-own-words.typ",
    "chapters/four-claims.typ",
    "chapters/writing-a-literate-program.typ",
    "chapters/reading-a-literate-program.typ",
    "chapters/when-not-to.typ",
    "chapters/differences-from-web.typ",
    "chapters/the-reader-that-is-not-a-person.typ",
    "chapters/package.typ",
    "chapters/weave.typ",
    "chapters/errors.typ",
    "chapters/metadata.typ",
    "chapters/the-declarations-a-pass-works-from.typ",
    "chapters/expanding-a-reference.typ",
    "chapters/what-a-pass-plans.typ",
    "chapters/writing-the-pass.typ",
    "chapters/carrying-the-book.typ",
    "chapters/what-the-binary-carries.typ",
    "chapters/reading-a-diagnostic-back.typ",
    "chapters/where-each-generated-line-came-from.typ",
    "chapters/who-owns-the-output-directory.typ",
    "chapters/the-ownership-rules-pinned.typ",
    "chapters/the-command-line.typ",
    "chapters/dispatch.typ",
    "chapters/the-rules.typ",
    "chapters/the-example.typ",
    "chapters/how-the-tests-are-written.typ",
    "chapters/tests-flow.typ",
    "chapters/tests-lazy.typ",
    "chapters/tests-metadata.typ",
    "chapters/tests-owned.typ",
    "chapters/tests-self.typ",
    "chapters/the-build-environment.typ",
    "chapters/the-programs-own-pipeline.typ",
    "chapters/this-repository.typ",
    "chapters/what-comes-from-outside.typ",
    "chapters/appendix-what-is-pinned.typ",
  ),
))

#include "chapters/the-tool-in-its-own-words.typ"

= Part I — Writing a literate program

#include "chapters/four-claims.typ"

#include "chapters/writing-a-literate-program.typ"

#include "chapters/reading-a-literate-program.typ"

#include "chapters/when-not-to.typ"

#include "chapters/differences-from-web.typ"

#include "chapters/the-reader-that-is-not-a-person.typ"

= Part II — The tool

#include "chapters/package.typ"

#include "chapters/weave.typ"

#include "chapters/errors.typ"

#include "chapters/metadata.typ"

#include "chapters/the-declarations-a-pass-works-from.typ"

#include "chapters/expanding-a-reference.typ"

#include "chapters/what-a-pass-plans.typ"

#include "chapters/writing-the-pass.typ"

#include "chapters/carrying-the-book.typ"

#include "chapters/what-the-binary-carries.typ"

#include "chapters/reading-a-diagnostic-back.typ"

#include "chapters/where-each-generated-line-came-from.typ"

#include "chapters/who-owns-the-output-directory.typ"

#include "chapters/the-ownership-rules-pinned.typ"

#include "chapters/the-command-line.typ"

#include "chapters/dispatch.typ"

#include "chapters/the-rules.typ"

= Part III — This repository

#include "chapters/the-example.typ"

#include "chapters/how-the-tests-are-written.typ"

#include "chapters/tests-flow.typ"

#include "chapters/tests-lazy.typ"

#include "chapters/tests-metadata.typ"

#include "chapters/tests-owned.typ"

#include "chapters/tests-self.typ"

#include "chapters/the-build-environment.typ"

#include "chapters/the-programs-own-pipeline.typ"

#include "chapters/this-repository.typ"

#include "chapters/what-comes-from-outside.typ"

#include "chapters/appendix-what-is-pinned.typ"
