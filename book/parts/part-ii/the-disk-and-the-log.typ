#import "../../package/lib.typ": chunk, file

= The disk, and the log

Every command in this tool either answers a question or changes something, and the two are kept apart by
where they go. An answer is data, and it belongs on standard output, where a program can read it. A change
is a log line, and it belongs on standard error, where a person can read it. Nothing in this tool writes a
sentence to standard output, and nothing in it writes a byte to the disk outside this chapter.

That is the whole reason the chapter exists. A rule about logging is a rule nobody keeps — there is always
one more place that writes a file — so instead of a rule there is one door: every write, every removal, and
every read of a file goes through the functions below, and each of them says so. The log cannot miss an operation the
tool did, because there is no other way to do one.

The levels are not decoration either. A real change to the outside world is `INFO`, because it is the thing
an operator wants to see after the fact: this file was written, that file was removed, this page was
rendered. A read is `DEBUG`, because reads are how the tool decides what to change, and a pass reads every
file it is about to leave alone. `INFO` by default, then, means a quiet command is a command that changed
nothing.

#file("src/disk.rs", ````rust
<<disk: the imports>>

<<disk: writing a file>>

<<disk: removing>>

<<disk: a directory>>

<<disk: reading>>
````)

== Why a module and not a habit

The alternative — a rule in the book saying that every write should be logged, and thirty call sites each
remembering — has a failure mode that shows up months later, in one command, in one branch, and only when
somebody is looking for a file that was written and never mentioned. A door cannot forget. It also removes
a repetition that was already there: `create_dir_all` for the parent of a path is not something each caller
should have to remember, and now nobody does.

What this costs is a type: `write` takes bytes rather than a `String`, so a caller that has text says
`as_bytes` or passes something that already is bytes. That is the kind of cost worth paying once, at the
door, rather than at every caller.

== What the log is for, and what it is not

The log records what the tool did to the disk. It is not the tool's report to a reader: what a pass would
write, which fragments nobody references, which files are nobody's — those are answers, and answers are
data, on standard output. Every answer is also a log line at `DEBUG`, which is how a person reads it command
by command, while `INFO` stays what it was: the record of a change. A person reading a log wants to know what
happened; a program reading standard output wants to know what is true. Keeping the two apart is what lets
`etch tangle etch.typ | jq` mean something.
#chunk("disk: the imports", ````rust
use std::path::Path;

use tracing::{debug, info};

use crate::diag::EtchError;
````)

#chunk("disk: writing a file", ````rust
pub fn write(path: &Path, bytes: impl AsRef<[u8]>) -> Result<(), EtchError> {
    let bytes = bytes.as_ref();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|err| EtchError::io(parent, err))?;
    }
    std::fs::write(path, bytes).map_err(|err| EtchError::io(path, err))?;
    info!(path = %path.display(), bytes = bytes.len(), "wrote a file");
    Ok(())
}
````)

#chunk("disk: removing", ````rust
pub fn remove_file(path: &Path) -> Result<(), EtchError> {
    std::fs::remove_file(path).map_err(|err| EtchError::io(path, err))?;
    info!(path = %path.display(), "removed a file");
    Ok(())
}

pub fn remove_dir_all(path: &Path) -> Result<(), EtchError> {
    std::fs::remove_dir_all(path).map_err(|err| EtchError::io(path, err))?;
    info!(path = %path.display(), "removed a directory");
    Ok(())
}

pub fn remove_dir(path: &Path) -> Result<(), EtchError> {
    std::fs::remove_dir(path).map_err(|err| EtchError::io(path, err))?;
    info!(path = %path.display(), "removed a directory");
    Ok(())
}
````)

#chunk("disk: reading", ````rust
pub fn read(path: &Path) -> Result<String, EtchError> {
    let text = std::fs::read_to_string(path).map_err(|err| EtchError::io(path, err))?;
    debug!(path = %path.display(), bytes = text.len(), "read a text file");
    Ok(text)
}

pub fn read_ok(path: &Path) -> Result<Option<String>, EtchError> {
    match read(path) {
        Ok(text) => Ok(Some(text)),
        Err(_) if !path.exists() => Ok(None),
        Err(err) => Err(err),
    }
}

pub fn read_bytes(path: &Path) -> Result<Vec<u8>, EtchError> {
    let bytes = std::fs::read(path).map_err(|err| EtchError::io(path, err))?;
    debug!(path = %path.display(), bytes = bytes.len(), "read a file");
    Ok(bytes)
}

pub fn read_bytes_ok(path: &Path) -> Result<Option<Vec<u8>>, EtchError> {
    match read_bytes(path) {
        Ok(bytes) => Ok(Some(bytes)),
        Err(_) if !path.exists() => Ok(None),
        Err(err) => Err(err),
    }
}
````)
#chunk("disk: a directory", ````rust
pub fn entries(path: &Path) -> Result<Vec<std::fs::DirEntry>, EtchError> {
    let entries = std::fs::read_dir(path)
        .map_err(|err| EtchError::io(path, err))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|err| EtchError::io(path, err))?;
    debug!(path = %path.display(), entries = entries.len(), "read a directory");
    Ok(entries)
}
````)
