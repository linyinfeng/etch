#import "../../package/lib.typ": chunk, file

= How an error is reported

Every failure in this program is one type, and it carries two things: what went wrong, and what to do about
it. There are no source spans: Typst gives the script layer no source positions, and the only ways to get one
would be to search the source text or to parse Typst a second time — neither of which this document is
willing to do for the sake of an underline (D14). What an error carries instead is the chunk it came from,
and the line it is quoting.

The type is deliberately small: a message, an optional help, and the three constructors the callers actually
need. Rendering is not its business — everything that turns one of these into something a terminal can print
lives in `main.rs` — so no module that reports a failure has to know what a failure looks like on a page.

#file("src/diag.rs", ````rust
<<diag: the imports>>

<<diag: what an error carries>>

impl EtchError {
    <<diag: a plain error>>

    <<diag: adding advice>>

    <<diag: the io case>>
}

<<diag: what a terminal needs>>

<<diag: the standard error trait>>

<<diag: what miette needs>>
````)

== The error, and why it carries no position

Two fields: a message and an optional help. A position is the third field a programmer expects, and its
absence is a decision with a price — the compiler's position has to be turned back into a declaration after
the fact, which is what the chapter on reading a diagnostic back is about.

#chunk("diag: the imports", ````rust
use std::fmt;
````)

#chunk("diag: what an error carries", ````rust
#[derive(Debug)]
pub struct EtchError {
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
impl fmt::Display for EtchError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}
````)

#chunk("diag: the standard error trait", ````rust
impl std::error::Error for EtchError {}
````)

#chunk("diag: what miette needs", ````rust
impl miette::Diagnostic for EtchError {
    fn help(&self) -> Option<Box<dyn fmt::Display + '_>> {
        self.help
            .as_ref()
            .map(|help| Box::new(help.clone()) as Box<dyn fmt::Display + '_>)
    }
}
````)
