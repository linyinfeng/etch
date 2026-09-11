//! `lp watch`: keep the generated files in step with the document while it is
//! being edited, and fuse the check loop in.
//!
//! Three properties matter more than raw speed here:
//!
//! 1. **Only real changes are written.** A pass compares the tangled bytes with
//!    what is on disk, so files that did not change keep their mtime — cargo and
//!    rust-analyzer stay asleep instead of rebuilding the world on every keypress.
//! 2. **Half-written documents are not tangled.** Mid-edit states are normal, so a
//!    syntax error prints and skips the pass, leaving the last good output alone.
//! 3. **Editor events are coalesced.** `notify`'s debouncer plus draining our own
//!    writes means one pass per burst, not one per keystroke.
//!
//! ponytail: every pass re-reads and re-parses the whole document and re-expands
//! every root (measured: ~1ms for 2k lines, see agent-notes). Reverse-reachability
//! and `typst-syntax`'s reparser are only worth it if that ever shows up in a
//! profile on a book-sized document.

use std::path::{Path, PathBuf};
use std::sync::mpsc;
use std::time::{Duration, Instant};

use notify_debouncer_full::notify::RecursiveMode;
use notify_debouncer_full::{DebounceEventResult, new_debouncer};

use crate::diag::LpError;
use crate::map::LpMap;
use crate::parse::Doc;
use crate::tangle;

pub struct Options {
    pub docs: Vec<PathBuf>,
    pub out: PathBuf,
    pub debounce: Duration,
    /// Run after a pass that changed something, e.g.
    /// `cargo build --message-format=short`.
    pub check_cmd: Option<String>,
}

pub fn run(options: Options) -> Result<(), LpError> {
    let (tx, rx) = mpsc::channel();
    let mut debouncer = new_debouncer(
        options.debounce,
        None,
        move |result: DebounceEventResult| {
            if result.is_ok() {
                let _ = tx.send(());
            }
        },
    )
    .map_err(|err| LpError::plain(format!("cannot start the file watcher: {err}")))?;

    // Watch the containing directories, not the files: editors save by renaming a
    // temporary file over the target, which drops a file-level watch.
    let mut watched: Vec<PathBuf> = Vec::new();
    for doc in &options.docs {
        let dir = doc
            .parent()
            .filter(|p| !p.as_os_str().is_empty())
            .unwrap_or(Path::new("."))
            .to_path_buf();
        if watched.contains(&dir) {
            continue;
        }
        debouncer
            .watch(&dir, RecursiveMode::NonRecursive)
            .map_err(|err| LpError::plain(format!("cannot watch {}: {err}", dir.display())))?;
        watched.push(dir);
    }

    eprintln!(
        "watching {} -> {}",
        options
            .docs
            .iter()
            .map(|doc| doc.display().to_string())
            .collect::<Vec<_>>()
            .join(", "),
        options.out.display()
    );

    pass(&options, true, &rx);
    while rx.recv().is_ok() {
        pass(&options, false, &rx);
    }
    Ok(())
}

/// One pass. `initial` only changes the wording when there is nothing to do.
/// Returns whether the pass rewrote anything.
fn pass(options: &Options, initial: bool, events: &mpsc::Receiver<()>) -> bool {
    let started = Instant::now();

    // Drop events queued while we were working (our own writes included) so a
    // single edit cannot trigger a second, useless pass.
    while events.try_recv().is_ok() {}

    let docs = match options
        .docs
        .iter()
        .map(|path| Doc::load(path))
        .collect::<Result<Vec<_>, _>>()
    {
        Ok(docs) => docs,
        Err(err) => {
            report(err);
            return false;
        }
    };

    let outcome = match tangle::run(&docs, &options.out, false) {
        Ok(outcome) => outcome,
        Err(err) => {
            report(err);
            return false;
        }
    };

    for warning in &outcome.warnings {
        eprintln!("warning: {warning}");
    }

    let ms = started.elapsed().as_secs_f64() * 1000.0;
    if outcome.changed.is_empty() {
        if initial {
            eprintln!(
                "sync   up to date ({} files, {ms:.1}ms)",
                outcome.unchanged.len()
            );
        }
        return false;
    }

    eprintln!(
        "sync   {} rewritten, {} untouched ({ms:.1}ms): {}",
        outcome.changed.len(),
        outcome.unchanged.len(),
        outcome
            .changed
            .iter()
            .map(|output| output.root.as_str())
            .collect::<Vec<_>>()
            .join(", ")
    );

    check(options);
    true
}

fn check(options: &Options) {
    let Some(command) = &options.check_cmd else {
        return;
    };

    let output = match std::process::Command::new("sh")
        .arg("-c")
        .arg(command)
        .output()
    {
        Ok(output) => output,
        Err(err) => {
            eprintln!("check  cannot run {command:?}: {err}");
            return;
        }
    };

    let text = format!(
        "{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );

    // Same translation as `lp explain`, reading the map we just wrote.
    match LpMap::read(&options.out) {
        Ok(map) => {
            let _ = crate::explain::run(&map, "generic", &text);
        }
        Err(_) => print!("{text}"),
    }
}

fn report(err: LpError) {
    eprintln!("{:?}", miette::Report::new(err));
}
