use std::fmt;
use std::ops::Range;

use miette::{Diagnostic, LabeledSpan, NamedSource, SourceCode, SourceSpan};

/// A user-facing error. Optionally points at a byte range in a `.typ` document,
/// which is what makes every message land on the line the reader must edit.
#[derive(Debug)]
pub struct LpError {
    message: String,
    snippet: Option<Box<Snippet>>,
    help: Option<String>,
}

#[derive(Debug)]
struct Snippet {
    src: NamedSource<String>,
    span: SourceSpan,
    label: String,
}

impl LpError {
    pub fn plain(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
            snippet: None,
            help: None,
        }
    }

    pub fn at(
        src: &NamedSource<String>,
        range: Range<usize>,
        message: impl Into<String>,
        label: impl Into<String>,
    ) -> Self {
        Self {
            message: message.into(),
            snippet: Some(Box::new(Snippet {
                src: src.clone(),
                span: SourceSpan::from((range.start, range.len())),
                label: label.into(),
            })),
            help: None,
        }
    }

    pub fn with_help(mut self, help: impl Into<String>) -> Self {
        self.help = Some(help.into());
        self
    }

    pub fn io(path: &std::path::Path, err: std::io::Error) -> Self {
        Self::plain(format!("{}: {err}", path.display()))
    }
}

impl fmt::Display for LpError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}

impl std::error::Error for LpError {}

impl Diagnostic for LpError {
    fn source_code(&self) -> Option<&dyn SourceCode> {
        self.snippet.as_ref().map(|s| &s.src as &dyn SourceCode)
    }

    fn labels(&self) -> Option<Box<dyn Iterator<Item = LabeledSpan> + '_>> {
        self.snippet.as_ref().map(|s| {
            let span = LabeledSpan::new(Some(s.label.clone()), s.span.offset(), s.span.len());
            Box::new(std::iter::once(span)) as Box<dyn Iterator<Item = LabeledSpan>>
        })
    }

    fn help(&self) -> Option<Box<dyn fmt::Display + '_>> {
        self.help
            .as_ref()
            .map(|help| Box::new(help.clone()) as Box<dyn fmt::Display + '_>)
    }
}
