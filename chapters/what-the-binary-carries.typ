#import "@local/lp:0.1.0": chunk, file

= What the binary carries

A tool that can only work inside its own repository is not finished. This one carries three things: the
program (it is the program), the package it declares chunks with, and — through the settings the document
carries — the book that produced the tree it was built from. `include_dir!` puts that directory in the binary
at compile time, so `lp self` needs nothing beside it.

#file("src/embedded.rs", ````rust
<<self: the imports>>

<<self: the book, carried>>

<<self: reading it>>

<<self: proving it>>
````)

*Three subcommands, three things it can do with what it carries:*

- `lp self book --out <dir>` writes the book out, entire: the document, the pointer, the ignore rules.
- `lp self read --format (pdf|html)` weaves the document *it carries* into a temporary directory and hands
  the result to the desktop. Weaving reuses `lp weave`, because there is one way to render a document and
  it should not be written twice; opening is best effort — a machine with no desktop still gets the file
  and its path. Either rendering carries the book with it — the block in a page, the attached files in a
  PDF — so what opens is something that can give its own source back.
- `lp self prove <dir>` unpacks that book into `<dir>`, tangles it with *this* binary, and runs the
  tree's own checks in it: the whole bootstrap in one command, with nothing outside the binary but the
  toolchain it borrows. The lock file is part of the book, so nix is asked not to resolve one — writing
  one there would be drift.

*And what it still needs, which is the other half of the same sentence:*

- `lp self book` needs nothing. The book is bytes in the binary.
- `lp self read` needs Typst: rendering is not this tool's work, so it borrows the compiler.
- `lp self prove` needs Typst and nix, and the second one is the point rather than an accident. The tree
  checks *itself* — `nix flake check` is the tree's own decision about itself, and it now renders this
  document and reads the book back out of both carriers, so the round trip is a condition of the package
  existing at all. A tool that ran those checks by hand would be claiming a guarantee it did not have.

`include_dir` is the one dependency this adds, and the line D7 asks for: embedding a directory tree is
`include_bytes!` at scale — one macro, no runtime dependency, and `Dir::extract` writes the tree back out
in a single call. It also embeds in *every* profile, which matters more than it sounds: a crate that reads
from the file system in debug builds would make the test below pass without embedding anything.

Four fragments follow: the imports, the embedded directory itself, and one function per subcommand — proving
last, because it is the one that uses the other two.

#chunk("self: the imports", ````rust
use std::path::{Path, PathBuf};
use std::process::Command;

use include_dir::{Dir, include_dir};

use crate::diag::LpError;

static BOOK: Dir = include_dir!("$CARGO_MANIFEST_DIR/book");
````)

#chunk("self: the book, carried", ````rust
pub fn book(out: &Path) -> Result<usize, LpError> {
    std::fs::create_dir_all(out).map_err(|err| LpError::io(out, err))?;
    BOOK.extract(out).map_err(|err| {
        LpError::plain(format!(
            "cannot write the book into {}: {err}",
            out.display()
        ))
    })?;
    Ok(BOOK.files().count())
}
````)

#chunk("self: proving it", ````rust
pub fn prove(dir: &Path) -> Result<i32, LpError> {
    let files = book(dir)?;

    let mut documents: Vec<PathBuf> = Vec::new();
    let entries = std::fs::read_dir(dir).map_err(|err| LpError::io(dir, err))?;
    for entry in entries {
        let path = entry.map_err(|err| LpError::io(dir, err))?.path();
        if path.extension().is_some_and(|kind| kind == "typ") {
            documents.push(path);
        }
    }
    if documents.len() != 1 {
        return Err(LpError::plain(format!(
            "the book carries {} .typ documents, not one",
            documents.len()
        ))
        .with_help("`lp self prove` expects the book to be a single document"));
    }

    let tree = dir.join("tangled");
    println!("wrote {files} files of the book to {}", dir.display());
    crate::tangle::run(&documents, &tree, false)?;

    let status = Command::new("nix")
        .args(["flake", "check", "--no-update-lock-file"])
        .current_dir(&tree)
        .status()
        .map_err(|err| LpError::plain(format!("cannot run nix: {err}")))?;
    Ok(status.code().unwrap_or(1))
}
````)

#chunk("self: reading it", ````rust
pub fn read(format: &str) -> Result<PathBuf, LpError> {
    let (name, flags): (&str, &[&str]) = match format {
        "pdf" => ("lp.pdf", &[]),
        "html" => ("lp.html", &["--features", "html"]),
        other => {
            return Err(LpError::plain(format!("unknown format {other:?}"))
                .with_help("`lp self read --format pdf`, or `--format html`"));
        }
    };

    let dir = std::env::temp_dir().join(format!("lp-self-{}", std::process::id()));
    std::fs::create_dir_all(&dir).map_err(|err| LpError::io(&dir, err))?;
    book(&dir)?;

    let document = dir.join("lp.typ");
    let output = dir.join(name);
    let flags: Vec<String> = flags.iter().map(|flag| flag.to_string()).collect();
    let status = crate::weave::run(&document, Some(&output), &flags)?;
    if status != 0 {
        return Err(LpError::plain(format!(
            "weaving {} failed with status {status}",
            document.display()
        )));
    }

    let _ = Command::new("xdg-open").arg(&output).spawn();
    Ok(output)
}
````)
