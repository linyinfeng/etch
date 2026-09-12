#import "@local/lp:0.1.0": chunk, file

= How an error is reported

Every failure in this program is one type, and it carries two things: what went wrong, and what to
do about it. There are no source spans — Typst gives no source positions, and a span could only
come from searching the source or parsing Typst again, which is not worth doing for the sake of an
underline (ADR D14). Errors name the chunk and quote the line instead.

The type is deliberately small: a message, an optional help, and the three constructors callers
actually need. Everything that renders it lives in one place (`main.rs`), so no module has to know
what an error looks like on a terminal.

== The shape of the file

#file("src/diag.rs", ````rust
<<diag: the imports>>

<<diag: what an error carries>>

impl LpError {
    <<diag: a plain error>>

    <<diag: adding advice>>

    <<diag: the io case>>
}

<<diag: what a terminal needs>>

<<diag: the standard error trait>>

<<diag: what miette needs>>
````)

== The error, and why it holds no positions

The file needs one import, and the error itself is two fields — a message and an optional
help. The reason there is no third field for a position is the subject of this section.

#chunk("diag: the imports", ````rust
use std::fmt;
````)

#chunk("diag: what an error carries", ````rust
#[derive(Debug)]
pub struct LpError {
    message: String,
    help: Option<String>,
}
````)

== Three constructors

`with_help` appends rather than replaces, which is what lets a layer close to the problem add its
own context without dropping what a lower layer already said. `io` exists because the path is the
only interesting part of an I/O error here: the file that could not be read or written is exactly
what the reader needs, and the rest is noise.

#chunk("diag: a plain error", ````rust
pub fn plain(message: impl Into<String>) -> Self {
    Self {
        message: message.into(),
        help: None,
    }
}
````)

#chunk("diag: adding advice", ````rust
pub fn with_help(mut self, help: impl Into<String>) -> Self {
    let help = help.into();
    self.help = Some(match self.help {
        Some(existing) => format!("{existing}\n{help}"),
        None => help,
    });
    self
}
````)

#chunk("diag: the io case", ````rust
pub fn io(path: &std::path::Path, err: std::io::Error) -> Self {
    Self::plain(format!("{}: {err}", path.display()))
}
````)

== The plumbing that lets miette render it

Three trait implementations and nothing else: `Display` writes the message, `Error` makes it an
error, and `Diagnostic` hands miette the help that was collected. The fancy rendering is one call
in `main.rs`; this file only promises that there is something to render.

#chunk("diag: what a terminal needs", ````rust
impl fmt::Display for LpError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}
````)

#chunk("diag: the standard error trait", ````rust
impl std::error::Error for LpError {}
````)

#chunk("diag: what miette needs", ````rust
impl miette::Diagnostic for LpError {
    fn help(&self) -> Option<Box<dyn fmt::Display + '_>> {
        self.help
            .as_ref()
            .map(|help| Box::new(help.clone()) as Box<dyn fmt::Display + '_>)
    }
}
````)

