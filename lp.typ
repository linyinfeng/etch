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
    "chapters/front/abstract.typ",
    "chapters/front/introduction.typ",
    "chapters/front/quick-start.typ",
    "chapters/front/the-tool-in-its-own-words.typ",
    "chapters/part-i/four-claims.typ",
    "chapters/part-i/writing-a-literate-program.typ",
    "chapters/part-i/reading-a-literate-program.typ",
    "chapters/part-i/when-not-to.typ",
    "chapters/part-i/differences-from-web.typ",
    "chapters/part-i/the-reader-that-is-not-a-person.typ",
    "chapters/part-ii/package.typ",
    "chapters/part-ii/weave.typ",
    "chapters/part-ii/errors.typ",
    "chapters/part-ii/the-disk-and-the-log.typ",
    "chapters/part-ii/metadata.typ",
    "chapters/part-ii/the-declarations-a-pass-works-from.typ",
    "chapters/part-ii/expanding-a-reference.typ",
    "chapters/part-ii/what-a-pass-plans.typ",
    "chapters/part-ii/writing-the-pass.typ",
    "chapters/part-ii/carrying-the-book.typ",
    "chapters/part-ii/what-the-binary-carries.typ",
    "chapters/part-ii/reading-a-diagnostic-back.typ",
    "chapters/part-ii/where-each-generated-line-came-from.typ",
    "chapters/part-ii/who-owns-the-output-directory.typ",
    "chapters/part-ii/the-ownership-rules-pinned.typ",
    "chapters/part-ii/the-command-line.typ",
    "chapters/part-ii/dispatch.typ",
    "chapters/part-ii/the-rules.typ",
    "chapters/part-iii/the-example.typ",
    "chapters/part-iii/how-the-tests-are-written.typ",
    "chapters/part-iii/tests-flow.typ",
    "chapters/part-iii/tests-lazy.typ",
    "chapters/part-iii/tests-metadata.typ",
    "chapters/part-iii/tests-owned.typ",
    "chapters/part-iii/tests-self.typ",
    "chapters/part-iii/the-build-environment.typ",
    "chapters/part-iii/the-programs-own-pipeline.typ",
    "chapters/part-iii/this-repository.typ",
    "chapters/part-iii/what-comes-from-outside.typ",
    "chapters/part-iii/appendix-what-is-pinned.typ",
  ),
))

#include "chapters/front/abstract.typ"

#include "chapters/front/introduction.typ"

#include "chapters/front/quick-start.typ"

#include "chapters/front/the-tool-in-its-own-words.typ"

= Part I — Writing a literate program

#include "chapters/part-i/four-claims.typ"

#include "chapters/part-i/writing-a-literate-program.typ"

#include "chapters/part-i/reading-a-literate-program.typ"

#include "chapters/part-i/when-not-to.typ"

#include "chapters/part-i/differences-from-web.typ"

#include "chapters/part-i/the-reader-that-is-not-a-person.typ"

= Part II — The tool

#include "chapters/part-ii/package.typ"

#include "chapters/part-ii/weave.typ"

#include "chapters/part-ii/errors.typ"

#include "chapters/part-ii/the-disk-and-the-log.typ"

#include "chapters/part-ii/metadata.typ"

#include "chapters/part-ii/the-declarations-a-pass-works-from.typ"

#include "chapters/part-ii/expanding-a-reference.typ"

#include "chapters/part-ii/what-a-pass-plans.typ"

#include "chapters/part-ii/writing-the-pass.typ"

#include "chapters/part-ii/carrying-the-book.typ"

#include "chapters/part-ii/what-the-binary-carries.typ"

#include "chapters/part-ii/reading-a-diagnostic-back.typ"

#include "chapters/part-ii/where-each-generated-line-came-from.typ"

#include "chapters/part-ii/who-owns-the-output-directory.typ"

#include "chapters/part-ii/the-ownership-rules-pinned.typ"

#include "chapters/part-ii/the-command-line.typ"

#include "chapters/part-ii/dispatch.typ"

#include "chapters/part-ii/the-rules.typ"

= Part III — This repository

#include "chapters/part-iii/the-example.typ"

#include "chapters/part-iii/how-the-tests-are-written.typ"

#include "chapters/part-iii/tests-flow.typ"

#include "chapters/part-iii/tests-lazy.typ"

#include "chapters/part-iii/tests-metadata.typ"

#include "chapters/part-iii/tests-owned.typ"

#include "chapters/part-iii/tests-self.typ"

#include "chapters/part-iii/the-build-environment.typ"

#include "chapters/part-iii/the-programs-own-pipeline.typ"

#include "chapters/part-iii/this-repository.typ"

#include "chapters/part-iii/what-comes-from-outside.typ"

#include "chapters/part-iii/appendix-what-is-pinned.typ"
