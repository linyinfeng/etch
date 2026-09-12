#import "@local/lp:0.1.0": chunk, file

= Keeping the files in step while the document is edited

`lp watch` is what makes the document usable as a source: save, and the generated files
follow. It is possible at all because of where the work is: a pass over this document — 8,900 lines, 38
output files — spends about a second and a half in the one call to Typst that reads the declarations, and
milliseconds on everything this tool does with them. The loop also exists because of a failure that is easy to
underestimate: a tool that rebuilds the world on every keystroke teaches its user to stop saving, and that is
the end of the loop the whole thing depends on.

Three properties matter more than speed, and each one is visible in the file. Only real changes are
written, so a file that did not change keeps its mtime and cargo and rust-analyzer stay asleep. A
half-written document is not tangled: a syntax error is printed and the pass is skipped, which leaves the last
good output in place while the editor is mid-keystroke. And editor events are coalesced — a debouncer plus
draining the events our own writes produced — so a burst of edits is one pass.

The cost is not hidden: every pass prints what it rewrote and how long it took. The design behind that
number is a deliberate ceiling — the whole document is re-read, re-evaluated and re-expanded every time — so
the part that grows with the book is the one call to Typst. If a document ever makes that hurt, that call is
the thing to attack; the expansion is not.

#file("src/watch.rs", ````rust
<<watch: the imports>>

<<watch: what the command line passes in>>

pub fn run(options: Options) -> Result<(), LpError> {
    <<watch: one debouncer, one channel>>

    <<watch: the directories, not the files>>

    <<watch: say what is being watched>>

    <<watch: pass once, then wait>>
    Ok(())
}

fn pass(options: &Options, initial: bool, events: &mpsc::Receiver<()>) -> bool {
    let started = Instant::now();

    <<watch: the events our own writes caused>>

    <<watch: one pass, through tangle>>

    <<watch: the warnings, and how long it took>>

    <<watch: nothing to do>>

    <<watch: say what happened, then check>>
    true
}

fn check(options: &Options) {
    <<watch: no check command, no check>>

    <<watch: run the command, whatever it is>>

    <<watch: its output, both streams>>

    <<watch: the same translation as lp explain>>
}

<<watch: the last resort>>
````)

== What the command line passes in

The watched documents, the output directory, the debounce window, and an optional command to
run after a pass that changed something. Nothing here knows about `lp` itself; this is the
part of the program that touches the outside world.

#chunk("watch: the imports", ````rust
use std::path::{Path, PathBuf};
use std::sync::mpsc;
use std::time::{Duration, Instant};

use notify_debouncer_full::notify::RecursiveMode;
use notify_debouncer_full::{DebounceEventResult, new_debouncer};

use crate::diag::LpError;
use crate::tangle;
````)

#chunk("watch: what the command line passes in", ````rust
pub struct Options {
    pub docs: Vec<PathBuf>,
    pub out: PathBuf,
    pub debounce: Duration,
    pub check_cmd: Option<String>,
}
````)

== Starting up, and what to watch

Three fragments: the debouncer and its channel, the directories to watch, and the line that says
what is being watched.

#chunk("watch: one debouncer, one channel", ````rust
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
````)

#chunk("watch: the directories, not the files", ````rust
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
````)

The directories are watched rather than the files, and that is not a detail: editors save by
writing a temporary file and renaming it over the target, which silently kills a watch on the
file itself. Watching the directory is also why the first pass matters — the loop has to be
correct *before* the first event arrives, since the document may already be out of step.

#chunk("watch: say what is being watched", ````rust
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
````)

#chunk("watch: pass once, then wait", ````rust
pass(&options, true, &rx);
while rx.recv().is_ok() {
    pass(&options, false, &rx);
}
````)

== One pass

A pass is four decisions in a row: drop the events our own writes caused, tangle, decide what to
report, and run the check command only if something actually moved.

#chunk("watch: the events our own writes caused", ````rust
while events.try_recv().is_ok() {}
````)

The drain is the part that is easy to miss: a pass writes files, the watcher sees those
writes, and without emptying the queue first every pass would trigger one more. This is also
where the design's honesty shows: the tool's own output is nobody's edit.

#chunk("watch: one pass, through tangle", ````rust
let outcome = match tangle::run(&options.docs, &options.out, false) {
    Ok(outcome) => outcome,
    Err(err) => {
        report(err);
        return false;
    }
};
````)

A failed pass does not end the loop — the error is printed and the pass returns without
writing anything, which is the half-written document case. The alternative, exiting, would
turn a moment of typing into a dead process.

#chunk("watch: the warnings, and how long it took", ````rust
for warning in &outcome.warnings {
    eprintln!("warning: {warning}");
}
let ms = started.elapsed().as_secs_f64() * 1000.0;
let dormant = outcome.changed.is_empty();
````)

#chunk("watch: nothing to do", ````rust
if dormant {
    if initial {
        eprintln!(
            "sync   up to date ({} files, {ms:.1}ms)",
            outcome.unchanged.len()
        );
    }
    return false;
}
````)

#chunk("watch: say what happened, then check", ````rust
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
if !dormant {
    check(options);
}
````)

== The check command

Running the check only when something was rewritten is the fusion that makes `--check-cmd`
worth having: a compiler invoked on every save would spend the user's morning rebuilding
nothing, and a warning printed on every save is a warning nobody reads.

#chunk("watch: no check command, no check", ````rust
let Some(command) = &options.check_cmd else {
    return;
};
````)

#chunk("watch: run the command, whatever it is", ````rust
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
````)

#chunk("watch: its output, both streams", ````rust
let text = format!(
    "{}{}",
    String::from_utf8_lossy(&output.stdout),
    String::from_utf8_lossy(&output.stderr)
);
````)

Both streams, because compilers are not consistent about which one carries the diagnostic —
cargo writes errors to stderr and notes to stdout, and a filter that reads one of them is
wrong half the time.

#chunk("watch: the same translation as lp explain", ````rust
let _ = crate::explain::run(&options.out, &text);
````)

== The last resort

Three lines, and the point of them is that they are not a special case: printing an error with
the renderer installed in `main` and staying alive is what a watcher has to do with every failure
that is not the user's syntax error.

#chunk("watch: the last resort", ````rust
fn report(err: LpError) {
    eprintln!("{:?}", miette::Report::new(err));
}
````)
