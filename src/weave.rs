use std::path::Path;
use std::process::Command;

use crate::diag::EtchError;
use crate::metadata::{binary, common_ancestor};

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
