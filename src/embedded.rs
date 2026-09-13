use std::path::{Path, PathBuf};
use std::process::Command;

use include_dir::{Dir, include_dir};
use tracing::debug;

use crate::diag::EtchError;
use crate::disk;

static BOOK: Dir = include_dir!("$CARGO_MANIFEST_DIR/book");

pub fn book(out: &Path) -> Result<usize, EtchError> {
    write(&BOOK, out)
}

fn write(dir: &Dir, out: &Path) -> Result<usize, EtchError> {
    let mut written = 0;
    for file in dir.files() {
        let path = out.join(file.path());
        disk::write(&path, file.contents())?;
        written += 1;
    }
    for sub in dir.dirs().filter(|sub| !scratch(sub)) {
        written += write(sub, out)?;
    }
    Ok(written)
}

fn scratch(dir: &Dir) -> bool {
    dir.path()
        .file_name()
        .is_some_and(|name| name == crate::metadata::PACKAGE_ROOT)
}

pub fn read(format: &str) -> Result<PathBuf, EtchError> {
    let (name, flags): (&str, &[&str]) = match format {
        "pdf" => ("etch.pdf", &[]),
        "html" => ("etch.html", &["--features", "html"]),
        other => {
            return Err(EtchError::plain(format!("unknown format {other:?}"))
                .with_help("`etch self read --format pdf`, or `--format html`"));
        }
    };

    let dir = std::env::temp_dir().join(format!("etch-self-{}", std::process::id()));
    book(&dir)?;

    let document = dir.join("etch.typ");
    let output = dir.join(name);
    let flags: Vec<String> = flags.iter().map(|flag| flag.to_string()).collect();
    let status = crate::weave::run(&document, Some(&output), &flags)?;
    if status != 0 {
        return Err(EtchError::plain(format!(
            "weaving {} failed with status {status}",
            document.display()
        )));
    }

    let _ = Command::new("xdg-open").arg(&output).spawn();
    Ok(output)
}

pub fn prove(dir: &Path) -> Result<i32, EtchError> {
    let files = book(dir)?;

    let mut documents: Vec<PathBuf> = Vec::new();
    let entries = disk::entries(dir)?;
    for entry in entries {
        let path = entry.path();
        if path.extension().is_some_and(|kind| kind == "typ") {
            documents.push(path);
        }
    }
    if documents.len() != 1 {
        return Err(EtchError::plain(format!(
            "the book carries {} .typ documents, not one",
            documents.len()
        ))
        .with_help("`etch self prove` expects the book to be a single document"));
    }

    let tree = dir.join("tangled");
    debug!("wrote {files} files of the book to {}", dir.display());
    crate::tangle::run(&documents, &tree, false)?;

    let status = Command::new("nix")
        .args(["flake", "check", "--no-update-lock-file"])
        .current_dir(&tree)
        .status()
        .map_err(|err| EtchError::plain(format!("cannot run nix: {err}")))?;
    Ok(status.code().unwrap_or(1))
}
