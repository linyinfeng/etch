#import "../../package/lib.typ": chunk, file

= Weaving the document

Tangling writes the program; weaving renders the document you are reading. The second is Typst's job, and
it is already done — `typst compile` renders a document. A second renderer inside this tool would be a
second thing to keep in step with the compiler, which is the kind of duplication this document keeps
refusing.

What the tool does have, and a writer should not have to remember, is where the document sits: `etch weave` is
`typst compile` with a root that covers the document, and every other argument passed through untouched:

```sh
etch weave etch.typ etch.pdf                          # the book, as Typst renders it
etch weave report.typ report.pdf --input who=me   # ... with Typst's own flags
```

#file("src/weave.rs", ````rust
<<weave: the imports>>

<<weave: the command>>

<<weave: the status>>
````)

== What the tool has to say, and what it does not

One fact, and it is one the tool already knows from tangling: a root that covers the document *and* the
working directory, because Typst refuses to read outside its root and an import that resolves through a
relative path has to stay inside it.

Everything else is Typst's, and is passed on as it came. That is why the arguments are trailing: after the
document and the output, nothing is ours to interpret. Typst's experimental exports arrive the same way:
`etch weave etch.typ etch.html --features html` writes an HTML rendering, and Typst warns while doing it that the
format is still under development. That the tool has no list of which flags are allowed is the point.

#chunk("weave: the imports", ````rust
use std::path::Path;
use std::process::Command;

use crate::diag::EtchError;
use crate::metadata::{binary, common_ancestor};
````)

#chunk("weave: the command", ````rust
pub fn run(doc: &Path, output: Option<&Path>, extra: &[String]) -> Result<i32, EtchError> {
    let typst = binary()?;
    let cwd = std::env::current_dir()
        .map_err(|err| EtchError::plain(format!("cannot read the working directory: {err}")))?;
    let anchor = doc.canonicalize().map_err(|err| EtchError::io(doc, err))?;
    let docs = vec![anchor.clone()];
    let mut root = docs;
    root.push(cwd);

    let mut command = Command::new(typst);
    command
        .arg("compile")
        .arg(doc)
        .arg("--root")
        .arg(common_ancestor(&root));
    if let Some(output) = output {
        command.arg(output);
    }
    command.args(extra);
````)

#chunk("weave: the status", ````rust
    let status = command
        .status()
        .map_err(|err| EtchError::plain(format!("cannot run Typst: {err}")))?;
    if status.success() {
        carry_the_book(&anchor, output)?;
    }
    Ok(status.code().unwrap_or(1))
}

fn carry_the_book(anchor: &Path, output: Option<&Path>) -> Result<(), EtchError> {
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

Every rendering this command produces carries the book the document declares — the files `etch tangle` copies
beside the tree — so the page is self-describing: `etch extract` can take the book back out of a PDF or an
HTML file months later, in a tree that has none of the source in it.

In HTML the book is a *data block*: a `<script>` whose type is not JavaScript is data, not code, so the page
stays a valid page and a browser that ignores the block has lost nothing. The payload is the book as JSON,
keyed by the names the tree uses, with a version inside, because a format that cannot say which format it is
cannot be improved. What marks the block is the whole opening tag, not the text of the id: this document
says `etch-source` in prose — here, in this sentence — and the first version, which searched for the id as a
substring, found this sentence instead and failed on it. A marker has to be something a page cannot mention
by accident.

A PDF carries the book as attached files, and there the carrying is the tool's work for reasons that took a
wrong turn each to find. The tempting shape was to let the package attach its own book: `pdf.attach` is one
line and Typst does the rest. It cannot. A package cannot name the document's files, because Typst resolves
a path relative to the file the call is written in — so `etch.typ` inside a package means the package's own
directory, and there is no way to ask for the document's — and it cannot expand a pattern either, because
Typst has no `glob`. An HTML page is the other way round: the package *can* read the whole book and cannot
place a marked block, because its HTML export takes no attributes and the marker is an attribute. So both
carriers are written by the tool, on the file the compiler has just left behind.

Neither format is guessed: `extract` demands `--format` because a wrong guess would produce silence rather
than an error, and each carrier is read back by what wrote it — the block by the same text handling, the
attached files by the PDF library that wrote them. `etch extract --format html|pdf <file> --out <dir>` writes
the book into `<dir>` under the book's own names, the same names `etch self book` writes, because where a
*tree* puts a book is a placement, not a property of the book.

== The editor needs no variable

The package is a file the document imports by the path it sits at, so an editor that renders the document
resolves it the way Typst resolves any relative import — the same file this command reads, with no package
path to set and nothing to unpack first. The document stays a normal Typst file, and the tool adds a root to
the compile rather than a dependency to the project.
