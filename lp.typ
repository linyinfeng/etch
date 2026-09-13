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
    "parts/front-matter/abstract.typ",
    "parts/front-matter/introduction.typ",
    "parts/front-matter/quick-start.typ",
    "parts/front-matter/the-tool-in-its-own-words.typ",
    "parts/part-i/four-claims.typ",
    "parts/part-i/the-reader-that-is-not-a-person.typ",
    "parts/part-i/writing-a-literate-program.typ",
    "parts/part-i/a-small-one-to-read-in-one-sitting.typ",
    "parts/part-i/reading-a-literate-program.typ",
    "parts/part-i/when-not-to.typ",
    "parts/part-i/differences-from-web.typ",
    "parts/part-ii/package.typ",
    "parts/part-ii/weave.typ",
    "parts/part-ii/errors.typ",
    "parts/part-ii/the-disk-and-the-log.typ",
    "parts/part-ii/metadata.typ",
    "parts/part-ii/the-declarations-a-pass-works-from.typ",
    "parts/part-ii/expanding-a-reference.typ",
    "parts/part-ii/what-a-pass-plans.typ",
    "parts/part-ii/writing-the-pass.typ",
    "parts/part-ii/carrying-the-book.typ",
    "parts/part-ii/what-the-binary-carries.typ",
    "parts/part-ii/reading-a-diagnostic-back.typ",
    "parts/part-ii/where-each-generated-line-came-from.typ",
    "parts/part-ii/who-owns-the-output-directory.typ",
    "parts/part-ii/the-ownership-rules-pinned.typ",
    "parts/part-ii/the-command-line.typ",
    "parts/part-ii/dispatch.typ",
    "parts/part-ii/the-rules.typ",
    "parts/part-iii/the-example.typ",
    "parts/part-iii/how-the-tests-are-written.typ",
    "parts/part-iii/tests-flow.typ",
    "parts/part-iii/tests-lazy.typ",
    "parts/part-iii/tests-metadata.typ",
    "parts/part-iii/tests-owned.typ",
    "parts/part-iii/tests-self.typ",
    "parts/part-iii/this-repository.typ",
    "parts/part-iii/the-build-environment.typ",
    "parts/part-iii/the-programs-own-pipeline.typ",
    "parts/part-iii/what-comes-from-outside.typ",
    "parts/part-iii/appendix-what-is-pinned.typ",
  ),
))

#include "parts/front-matter/abstract.typ"

#include "parts/front-matter/introduction.typ"

#include "parts/front-matter/quick-start.typ"

#include "parts/front-matter/the-tool-in-its-own-words.typ"

= Part I — Writing a literate program

#include "parts/part-i/four-claims.typ"

#include "parts/part-i/the-reader-that-is-not-a-person.typ"

#include "parts/part-i/writing-a-literate-program.typ"

#include "parts/part-i/a-small-one-to-read-in-one-sitting.typ"

#include "parts/part-i/reading-a-literate-program.typ"

#include "parts/part-i/when-not-to.typ"

#include "parts/part-i/differences-from-web.typ"

= Part II — The tool

#include "parts/part-ii/package.typ"

#include "parts/part-ii/weave.typ"

#include "parts/part-ii/errors.typ"

#include "parts/part-ii/the-disk-and-the-log.typ"

#include "parts/part-ii/metadata.typ"

#include "parts/part-ii/the-declarations-a-pass-works-from.typ"

#include "parts/part-ii/expanding-a-reference.typ"

#include "parts/part-ii/what-a-pass-plans.typ"

#include "parts/part-ii/writing-the-pass.typ"

#include "parts/part-ii/carrying-the-book.typ"

#include "parts/part-ii/what-the-binary-carries.typ"

#include "parts/part-ii/reading-a-diagnostic-back.typ"

#include "parts/part-ii/where-each-generated-line-came-from.typ"

#include "parts/part-ii/who-owns-the-output-directory.typ"

#include "parts/part-ii/the-ownership-rules-pinned.typ"

#include "parts/part-ii/the-command-line.typ"

#include "parts/part-ii/dispatch.typ"

#include "parts/part-ii/the-rules.typ"

= Part III — This repository

#include "parts/part-iii/the-example.typ"

#include "parts/part-iii/how-the-tests-are-written.typ"

#include "parts/part-iii/tests-flow.typ"

#include "parts/part-iii/tests-lazy.typ"

#include "parts/part-iii/tests-metadata.typ"

#include "parts/part-iii/tests-owned.typ"

#include "parts/part-iii/tests-self.typ"

#include "parts/part-iii/this-repository.typ"

#include "parts/part-iii/the-build-environment.typ"

#include "parts/part-iii/the-programs-own-pipeline.typ"

#include "parts/part-iii/what-comes-from-outside.typ"

#include "parts/part-iii/appendix-what-is-pinned.typ"
