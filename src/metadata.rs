use std::path::{Path, PathBuf};
use std::process::Command;

use serde::{Deserialize, Serialize};

use crate::diag::EtchError;
use crate::disk;

const QUERY: &str = "query(<etch-decl>).map(declaration => declaration.value)";

#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct Decl {
    pub etch: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub lang: Option<String>,
    #[serde(default)]
    pub text: String,
    #[serde(default)]
    pub options: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Chunk,
    File,
    Options,
}

impl Decl {
    pub fn kind(&self) -> Result<Kind, EtchError> {
        match self.etch.as_str() {
            "chunk" => Ok(Kind::Chunk),
            "file" => Ok(Kind::File),
            "options" => Ok(Kind::Options),
            other => Err(EtchError::plain(format!(
                "{}: unknown declaration kind {other:?}",
                self.name
            ))
            .with_help(
                "the package emits `etch: \"chunk\"`, `etch: \"file\"` or `etch: \"options\"`",
            )),
        }
    }
}

pub const PACKAGE_ROOT: &str = ".etch";

pub fn binary() -> Result<PathBuf, EtchError> {
    if let Some(path) = std::env::var_os("ETCH_TYPST") {
        return Ok(PathBuf::from(path));
    }
    let name = if cfg!(windows) { "typst.exe" } else { "typst" };
    std::env::var_os("PATH")
        .and_then(|paths| std::env::split_paths(&paths).map(|dir| dir.join(name)).find(|candidate| candidate.is_file()))
        .ok_or_else(|| {
            EtchError::plain("no `typst` binary found").with_help(
                "tangling asks the document for its declarations, so typst has to be available (set ETCH_TYPST or put it on PATH)",
            )
        })
}

pub fn declarations(typst: &Path, docs: &[PathBuf]) -> Result<Vec<Decl>, EtchError> {
    let cwd = std::env::current_dir()
        .map_err(|err| EtchError::plain(format!("cannot read the working directory: {err}")))?;
    let docs: Vec<PathBuf> = docs
        .iter()
        .map(|doc| std::path::absolute(doc).unwrap_or_else(|_| cwd.join(doc)))
        .collect();

    let root = common_ancestor(
        &docs
            .iter()
            .cloned()
            .chain([cwd.clone()])
            .collect::<Vec<_>>(),
    );
    let wrapper = Wrapper::write(&common_ancestor(&docs), &docs, false)?;
    let output = Command::new(typst)
        .arg("eval")
        .arg(QUERY)
        .arg("--in")
        .arg(&wrapper.path)
        .arg("--root")
        .arg(&root)
        .current_dir(&cwd)
        .output();
    drop(wrapper);

    let output =
        output.map_err(|err| EtchError::plain(format!("cannot run {}: {err}", typst.display())))?;
    if !output.status.success() {
        let message = String::from_utf8_lossy(&output.stderr);
        return Err(EtchError::plain(format!(
            "the document did not evaluate, so there are no chunks to tangle:\n{}",
            message.trim_end()
        )));
    }

    let declarations: Vec<Decl> = serde_json::from_slice(&output.stdout).map_err(|err| {
        EtchError::plain(format!("cannot read the document's declarations: {err}"))
            .with_help(String::from_utf8_lossy(&output.stdout).to_string())
    })?;
    for declaration in &declarations {
        declaration.kind()?;
    }
    Ok(declarations)
}

pub fn inputs(typst: &Path, docs: &[PathBuf]) -> Result<Vec<PathBuf>, EtchError> {
    let cwd = std::env::current_dir()
        .map_err(|err| EtchError::plain(format!("cannot read the working directory: {err}")))?;
    let docs: Vec<PathBuf> = docs
        .iter()
        .map(|doc| std::path::absolute(doc).unwrap_or_else(|_| cwd.join(doc)))
        .collect();

    let root = common_ancestor(
        &docs
            .iter()
            .cloned()
            .chain([cwd.clone()])
            .collect::<Vec<_>>(),
    );
    let wrapper = Wrapper::write(&common_ancestor(&docs), &docs, true)?;
    let list = common_ancestor(&docs)
        .join(PACKAGE_ROOT)
        .join(format!("deps-{}.json", std::process::id()));
    let laid_out = common_ancestor(&docs)
        .join(PACKAGE_ROOT)
        .join(format!("quiet-{}.pdf", std::process::id()));
    let output = Command::new(typst)
        .arg("compile")
        .arg("--deps")
        .arg(&list)
        .arg("--root")
        .arg(&root)
        .arg(&wrapper.path)
        .arg(&laid_out)
        .current_dir(&cwd)
        .output();
    drop(wrapper);
    let _ = disk::remove_file(&laid_out);

    let output =
        output.map_err(|err| EtchError::plain(format!("cannot run {}: {err}", typst.display())))?;
    if !output.status.success() {
        let _ = disk::remove_file(&list);
        let message = String::from_utf8_lossy(&output.stderr);
        return Err(EtchError::plain(format!(
            "the document did not evaluate, so there is no telling what it reads:\n{}",
            message.trim_end()
        )));
    }

    let text = disk::read(&list)?;
    let _ = disk::remove_file(&list);
    let report: Deps = serde_json::from_str(&text).map_err(|err| {
        EtchError::plain(format!("cannot read the list Typst wrote: {err}")).with_help(text.clone())
    })?;
    Ok(report
        .inputs
        .iter()
        .map(|input| {
            let beside_the_root = root.join(input);
            let candidate = if beside_the_root.exists() {
                beside_the_root
            } else {
                cwd.join(input)
            };
            std::fs::canonicalize(&candidate).unwrap_or(candidate)
        })
        .filter(|path| {
            !path
                .components()
                .any(|part| part.as_os_str() == crate::metadata::PACKAGE_ROOT)
        })
        .collect())
}

#[derive(Deserialize)]
struct Deps {
    inputs: Vec<String>,
}

struct Wrapper {
    path: PathBuf,
}

impl Wrapper {
    fn write(root: &Path, docs: &[PathBuf], quiet: bool) -> Result<Self, EtchError> {
        let path = root
            .join(PACKAGE_ROOT)
            .join(format!("entry-{}.typ", std::process::id()));
        let mut text = String::new();
        if quiet {
            text.push_str("#show: it => none\n");
        }
        for doc in docs {
            let relative = doc.strip_prefix(root).unwrap_or(doc);
            let quoted = relative
                .to_string_lossy()
                .replace('\\', "/")
                .replace('"', "\\\"");
            text.push_str(&format!("#include \"../{quoted}\"\n"));
        }
        disk::write(&path, text)?;
        Ok(Self { path })
    }
}

impl Drop for Wrapper {
    fn drop(&mut self) {
        let _ = disk::remove_file(&self.path);
    }
}

pub fn common_ancestor(docs: &[PathBuf]) -> PathBuf {
    let mut root = docs
        .first()
        .and_then(|doc| doc.parent())
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("/"));

    for doc in docs.iter().skip(1) {
        while !doc.starts_with(&root) {
            match root.parent() {
                Some(parent) => root = parent.to_path_buf(),
                None => return root,
            }
        }
    }
    root
}

#[cfg(test)]
mod tests {
    use super::common_ancestor;
    use std::path::{Path, PathBuf};

    #[test]
    fn the_wrapper_goes_where_every_document_lives() {
        assert_eq!(
            common_ancestor(&[
                PathBuf::from("/a/b/book.typ"),
                PathBuf::from("/a/b/chapter.typ")
            ]),
            Path::new("/a/b")
        );
        assert_eq!(
            common_ancestor(&[
                PathBuf::from("/a/book.typ"),
                PathBuf::from("/a/c/chapter.typ")
            ]),
            Path::new("/a")
        );
        assert_eq!(
            common_ancestor(&[PathBuf::from("/a/book.typ")]),
            Path::new("/a")
        );
    }
}
