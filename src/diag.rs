use std::fmt;

#[derive(Debug)]
pub struct EtchError {
    message: String,
    help: Option<String>,
}

impl EtchError {
    pub fn plain(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
            help: None,
        }
    }

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

impl fmt::Display for EtchError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}

impl std::error::Error for EtchError {}

impl miette::Diagnostic for EtchError {
    fn help(&self) -> Option<Box<dyn fmt::Display + '_>> {
        self.help
            .as_ref()
            .map(|help| Box::new(help.clone()) as Box<dyn fmt::Display + '_>)
    }
}
