//! Reading chunks out of a `.typ` document.
//!
//! A chunk is a fenced raw block that carries a Typst label — either on the
//! closing fence or on the line right after it:
//!
//! ```text
//! ```rust
//! fn main() {}
//! ``` <src/main.rs>
//! ```
//!
//! Typst's own parser (`typst-syntax`) gives us the body, the language tag and
//! exact byte spans, so we never re-implement fence or indentation handling.

use std::ops::Range;
use std::path::{Path, PathBuf};

use miette::NamedSource;
use typst_syntax::{LinkedNode, Source, SyntaxKind, ast};

use crate::diag::LpError;

pub struct Block {
    pub name: String,
    pub lang: Option<String>,
    pub text: String,
    /// 1-based line of the opening fence.
    pub fence_line: usize,
    pub span: Range<usize>,
}

pub struct Doc {
    pub path: PathBuf,
    pub text: String,
    pub src: NamedSource<String>,
    pub blocks: Vec<Block>,
}

impl Doc {
    pub fn load(path: &Path) -> Result<Self, LpError> {
        let text = std::fs::read_to_string(path).map_err(|e| LpError::io(path, e))?;
        let src = NamedSource::new(path.display().to_string(), text.clone());
        let source = Source::detached(text.clone());

        let mut blocks = Vec::new();
        walk(
            &LinkedNode::new(source.root()),
            &source,
            &text,
            &src,
            &mut blocks,
        )?;

        Ok(Self {
            path: path.to_path_buf(),
            text,
            src,
            blocks,
        })
    }

    /// Byte range of a 1-based line, without its newline. Used to point
    /// diagnostics at whole lines.
    pub fn line_range(&self, line: usize) -> Option<Range<usize>> {
        let mut offset = 0;
        for (i, text) in self.text.split_inclusive('\n').enumerate() {
            if i + 1 == line {
                return Some(offset..offset + text.trim_end_matches('\n').len());
            }
            offset += text.len();
        }
        None
    }
}

fn walk(
    node: &LinkedNode,
    src: &Source,
    text: &str,
    named: &NamedSource<String>,
    out: &mut Vec<Block>,
) -> Result<(), LpError> {
    if let Some(raw) = node.get().cast::<ast::Raw>()
        && raw.block()
        && let Some(sibling) = node.next_sibling()
        && let Some(name) = label_name(text, named, &sibling)?
    {
        let body = raw
            .lines()
            .map(|line| line.get().to_string())
            .collect::<Vec<_>>()
            .join("\n");

        out.push(Block {
            name,
            lang: raw.lang().map(|l| l.get().to_string()),
            text: body,
            fence_line: line_of(src, node.range().start),
            span: node.range(),
        });
    }

    for child in node.children() {
        walk(&child, src, text, named, out)?;
    }
    Ok(())
}

/// A chunk's name comes from the label attached to its code block. Typst's
/// dedicated label syntax only allows `[A-Za-z0-9_.:-]`, so names that need a
/// directory separator (or anything else) use the constructor instead:
///
/// ```text
/// ```rust ... ``` <imports>              // flat name
/// ```rust ... ``` #label("src/lib.rs")   // path
/// ```
fn label_name(
    text: &str,
    named: &NamedSource<String>,
    sibling: &LinkedNode,
) -> Result<Option<String>, LpError> {
    if sibling.get().kind() == SyntaxKind::Label {
        let label = sibling.get().leaf_text().trim();
        return Ok(Some(
            label
                .trim_start_matches('<')
                .trim_end_matches('>')
                .to_string(),
        ));
    }

    // `#label("src/lib.rs")` is a hash expression, so the call sits behind a Hash node.
    let range = match sibling.get().kind() {
        SyntaxKind::FuncCall => sibling.range(),
        SyntaxKind::Hash => match sibling
            .next_sibling()
            .filter(|next| next.get().kind() == SyntaxKind::FuncCall)
        {
            Some(call) => call.range(),
            None => return Ok(None),
        },
        _ => return Ok(None),
    };

    let call = &text[range.clone()];
    if !call.starts_with("label(") {
        return Ok(None);
    }

    let unsupported = || {
        LpError::at(
            named,
            range.clone(),
            format!("unsupported chunk label {call:?}"),
            "not a plain string literal",
        )
        .with_help("write `#label(\"src/main.rs\")` or `<main.rs>`")
    };
    let inner = call
        .strip_prefix("label(")
        .and_then(|rest| rest.strip_suffix(')'))
        .map(str::trim)
        .ok_or_else(unsupported)?;
    let name = inner
        .strip_prefix('"')
        .and_then(|rest| rest.strip_suffix('"'))
        .ok_or_else(unsupported)?;
    Ok(Some(name.replace("\\\"", "\"").replace("\\\\", "\\")))
}

fn line_of(src: &Source, byte: usize) -> usize {
    src.lines().byte_to_line(byte).map_or(0, |line| line + 1)
}

/// A chunk name that names a file is a *root*: tangling writes it to disk.
/// Everything else is a fragment that only appears where it is referenced.
pub fn is_root(name: &str) -> bool {
    let file = name.rsplit('/').next().unwrap_or(name);
    match file.rsplit_once('.') {
        Some((stem, ext)) => {
            !stem.is_empty() && !ext.is_empty() && ext.chars().all(|c| c.is_ascii_alphanumeric())
        }
        None => false,
    }
}

/// Reject names that would write outside the output directory.
pub fn check_output_path(name: &str) -> Result<(), LpError> {
    let unsafe_name = name.is_empty()
        || name.starts_with('/')
        || name.contains('\\')
        || Path::new(name).components().any(|c| {
            matches!(
                c,
                std::path::Component::ParentDir
                    | std::path::Component::RootDir
                    | std::path::Component::Prefix(_)
            )
        });

    if unsafe_name {
        return Err(LpError::plain(format!("unsafe chunk name {name:?}"))
            .with_help("root chunk names must be relative paths inside --out, without `..`"));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roots_are_names_that_look_like_files() {
        for name in ["main.c", "src/lib.rs", "Cargo.toml"] {
            assert!(is_root(name), "{name}");
        }
        for name in ["imports", "body", "v1", "notes.", ".hidden"] {
            assert!(!is_root(name), "{name}");
        }
    }

    #[test]
    fn output_paths_cannot_escape_the_output_directory() {
        assert!(check_output_path("src/lib.rs").is_ok());
        for name in ["", "/etc/passwd", "../escape", "a/../../escape", "a\\b"] {
            assert!(check_output_path(name).is_err(), "{name}");
        }
    }
}
