use std::fmt;

/// A user-facing error: what went wrong, and what to do about it.
///
/// No source spans. Typst gives no source positions, so a span could only come
/// from searching the source or parsing Typst again, and that is not worth doing
/// for the sake of an underline (ADR D14). Errors name the chunk and quote the
/// line instead.
#[derive(Debug)]
pub struct LpError {
    message: String,
    help: Option<String>,
}

impl LpError {
    pub fn plain(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
            help: None,
        }
    }

    /// Add advice. Repeated calls append, so a caller can add its own context
    /// without dropping what the error already said.
    pub fn with_help(mut self, help: impl Into<String>) -> Self {
        let help = help.into();
        self.help = Some(match self.help {
            Some(existing) => format!("{existing}\n{help}"),
            None => help,
        });
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

impl miette::Diagnostic for LpError {
    fn help(&self) -> Option<Box<dyn fmt::Display + '_>> {
        self.help
            .as_ref()
            .map(|help| Box::new(help.clone()) as Box<dyn fmt::Display + '_>)
    }
}
