#import "@local/lp:0.1.0": chunk, file

= Weaving the document

Tangling writes the program; weaving renders the document you are reading. The second is Typst's job, and
it is already done — `typst compile` renders a document. A second renderer inside this tool would be a
second thing to keep in step with the compiler, which is the kind of duplication this document keeps
refusing.

What the tool does have, and a writer should not have to remember, is where the package went. The document
imports `@local/lp:0.1.0`, and Typst resolves that through a package path: the directory the tangle
unpacked next to the document. `lp weave` is `typst compile` with that path filled in, a root that covers
the document, and every other argument passed through untouched:

```sh
lp weave lp.typ lp.pdf                          # the book, as Typst renders it
lp weave report.typ report.pdf --input who=me   # ... with Typst's own flags
```

#file("src/weave.rs", ````rust
<<weave: the imports>>

<<weave: the command>>

<<weave: the status>>
````)

== What the tool has to say, and what it does not

Two facts, and both are things the tool already knows from tangling:

- the package path, because it unpacked the package itself;
- a root that covers the document *and* the working directory, because Typst refuses to read outside its
  root and an import that resolves through a relative path has to stay inside it.

Everything else is Typst's, and is passed on as it came. That is why the arguments are trailing: after the
document and the output, nothing is ours to interpret. Typst's experimental exports arrive the same way:
`lp weave lp.typ lp.html --features html` writes an HTML rendering, and Typst warns while doing it that the
format is still under development. That the tool has no list of which flags are allowed is the point.

#chunk("weave: the imports", ````rust
use std::path::Path;
use std::process::Command;

use crate::diag::LpError;
use crate::metadata::{binary, common_ancestor, unpack_package};
````)

#chunk("weave: the command", ````rust
pub fn run(doc: &Path, output: Option<&Path>, extra: &[String]) -> Result<i32, LpError> {
    let typst = binary()?;
    let cwd = std::env::current_dir()
        .map_err(|err| LpError::plain(format!("cannot read the working directory: {err}")))?;
    let anchor = doc.canonicalize().map_err(|err| LpError::io(doc, err))?;
    let docs = vec![anchor.clone()];
    let packages = unpack_package(&common_ancestor(&docs))?;
    let mut root = docs;
    root.push(cwd);

    let mut command = Command::new(typst);
    command
        .arg("compile")
        .arg(doc)
        .arg("--root")
        .arg(common_ancestor(&root))
        .arg("--package-path")
        .arg(&packages);
    if let Some(output) = output {
        command.arg(output);
    }
    command.args(extra);
````)

#chunk("weave: the status", ````rust
    let status = command
        .status()
        .map_err(|err| LpError::plain(format!("cannot run Typst: {err}")))?;
    if status.success() {
        carry_the_book(&anchor, output)?;
    }
    Ok(status.code().unwrap_or(1))
}

fn carry_the_book(anchor: &Path, output: Option<&Path>) -> Result<(), LpError> {
    let Some(page) = output.filter(|out| {
        out.extension()
            .is_some_and(|ext| ext == "html" || ext == "pdf")
    }) else {
        return Ok(());
    };
    let Some(directory) = anchor.parent() else {
        return Ok(());
    };
    let docs = vec![anchor.to_path_buf()];
    let Some(book) = crate::tangle::declared_book(&docs)? else {
        return Ok(());
    };
    let copies = crate::book::plan(&book, directory)?;
    crate::book::attach(page, &book.directory, &copies)
}
````)

== The page carries the book

Every rendering this command produces carries the book the document declares — the files `lp tangle` copies
beside the tree — so the page is self-describing: `lp extract` can take the book back out of a PDF or an
HTML file months later, in a tree that has none of the source in it.

In HTML the book is a *data block*: a `<script>` whose type is not JavaScript is data, not code, so the page
stays a valid page and a browser that ignores the block has lost nothing. The payload is the book as JSON,
keyed by the names the tree uses, with a version inside, because a format that cannot say which format it is
cannot be improved. What marks the block is the whole opening tag, not the text of the id: this document
says `lp-source` in prose — here, in this sentence — and the first version, which searched for the id as a
substring, found this sentence instead and failed on it. A marker has to be something a page cannot mention
by accident.

A PDF carries the book as attached files, and there the carrying is the tool's work for reasons that took a
wrong turn each to find. The tempting shape was to let the package attach its own book: `pdf.attach` is one
line and Typst does the rest. It cannot. A package cannot name the document's files, because Typst resolves
a path relative to the file the call is written in — so `lp.typ` inside a package means the package's own
directory, and there is no way to ask for the document's — and it cannot expand a pattern either, because
Typst has no `glob`. An HTML page is the other way round: the package *can* read the whole book and cannot
place a marked block, because its HTML export takes no attributes and the marker is an attribute. So both
carriers are written by the tool, on the file the compiler has just left behind.

Neither format is guessed: `extract` demands `--format` because a wrong guess would produce silence rather
than an error, and each carrier is read back by what wrote it — the block by the same text handling, the
attached files by the PDF library that wrote them. `lp extract --format html|pdf <file> --out <dir>` writes
the book into `<dir>` under the book's own names, the same names `lp self book` writes, because where a
*tree* puts a book is a placement, not a property of the book.

== The editor, in one variable

The package is the copy embedded in this binary, unpacked fresh, so weaving needs no tangle before it: the
document is the source of both. And the document stays a normal Typst file — an editor rendering it without
the tool sets `TYPST_PACKAGE_PATH` itself, to the same path this command passes: `.lp/packages` under the
documents' directory.

That path is the whole editor story, and it works because nothing about it is ours to invent: the layout
below is `namespace/name/version`, which is what every Typst package looks like, and the namespace is
`local`, which is the one Typst recommends for a package that is not published. A language server that
follows Typst's conventions therefore needs that one variable and no configuration of its own. An editor
willing to touch the machine instead can link the same directory into Typst's data directory, and then no
project needs the variable at all.
