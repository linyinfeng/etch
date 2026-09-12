#import "@local/lp:0.1.0": chunk, file

= Who owns the output directory

Tangling writes into a directory that already holds things it did not write: a compiler's
build directory, a lock file, the PDF the weave produced, notes the user keeps there. A
tool that deleted or overwrote by guessing would be worse than useless in that position, so
this part of `lp` is a rule instead of a heuristic — and it is the reason `--check` can be
trusted.

== The rule

Point `--out` at a directory and that whole directory is `lp`'s, at any depth. Every file
under it falls into exactly one of three groups: produced by a `#file` declaration,
declared in the `.lpignore` of its directory, or neither. The third group is the only one
worth reporting, and it is reported as an error that names every entry.

Two halves of that rule are easy to get backwards, so they are worth saying plainly. The
declaration file is a list of what `lp` does *not* manage: matching means the file is
protected, which is the opposite of what the word "ignore" suggests. And `lp` never deletes
as a side effect of a pass — stale output is either declared, or removed by an explicit
`lp unaccounted --delete`.

Why report at all, rather than tidy up? Because the answer is unknowable from the inside. A
file that no chunk produces may be one a chunk *should* produce, a file the user put there,
or the output of a chunk that was deleted; only the user can tell which. So the tool lists
what it finds and stops.

#file("src/status.rs", ````rust
<<status: the imports>>

<<status: the file that says what lp does not manage>>

<<status: what a directory of strays looks like>>

pub fn unaccounted(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
) -> Result<Vec<Unaccounted>, LpError> {
    <<status: nothing to report>>

    <<status: ask the walker>>

    <<status: what survives the walk>>

    <<status: group them by directory>>
    <<status: sorted, and stable>>
}

<<status: what the tool writes is not content>>

<<status: when a subtree is too big to list>>

<<status: compressing a subtree>>

<<status: finding the subdirectories>>

<<status: delete, on request>>

<<status: cleaning up directories that emptied>>

pub fn run(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
    delete_unaccounted: bool,
) -> Result<i32, LpError> {
    <<status: nothing was declared>>

    <<status: everything is accounted for>>

    <<status: delete, when that is what was asked>>

    <<status: list them, and say what to do>>
}

<<status: the rules, pinned by four cases>>
````)

== Three groups, and the file's own opening

The module note states the model in the file itself, which is where a reader who opens
`src/status.rs` needs it; the rest of this chapter is why each piece is shaped that way.

#chunk("status: the imports", ````rust
use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

use ignore::WalkBuilder;

use crate::diag::LpError;
use crate::map::{MAP_FILE, relative};
````)

== One name is the contract

A constant, because the name is part of the interface: a directory declares what `lp` does
not manage in exactly this file, and the walker below is told to look for this name instead
of git's default.

#chunk("status: the file that says what lp does not manage", ````rust
pub const IGNORE_FILE: &str = ".lpignore";
````)

== What a directory of strays looks like

The report is grouped by directory, because the fix is per directory: each group is one
directory and the entries nothing accounts for inside it. An entry that ends in a slash
means a whole subtree was compressed into one line — which is why entries are strings and
not paths.

#chunk("status: what a directory of strays looks like", ````rust
#[derive(Debug)]
pub struct Unaccounted {
    pub dir: String,
    pub entries: Vec<String>,
}
````)

== Walking the tree, and what survives it

The walk and the filter are separate fragments because they answer different questions: what is
under the output directory, and which of those files nothing accounts for.

#chunk("status: nothing to report", ````rust
if produced.is_empty() || !out.exists() {
    return Ok(Vec::new());
}
````)

#chunk("status: ask the walker", ````rust
let mut builder = WalkBuilder::new(out);
builder
    .standard_filters(false)
    .hidden(false)
    .parents(false)
    .add_custom_ignore_filename(IGNORE_FILE);
````)

The walker is the crate git itself uses, with its default filters switched off — this is not
a git question — and `.lpignore` registered as *the* ignore file name. That choice is the
whole reason there is no second implementation of ignore rules here: nesting, deepest-wins,
whitelists and the `!` operator are the library's job, and a directory that declares
something is simply never visited.

#chunk("status: what survives the walk", ````rust
let mut files: BTreeSet<String> = BTreeSet::new();
for entry in builder.build() {
    let entry =
        entry.map_err(|err| LpError::plain(format!("cannot scan {}: {err}", out.display())))?;
    if entry.file_type().is_some_and(|kind| kind.is_dir()) {
        continue;
    }
    let path = entry.path();
    if is_own_output(path) {
        continue;
    }
    let rel = relative(out, path);
    if rel
        .split('/')
        .any(|part| part == crate::metadata::PACKAGE_ROOT)
    {
        continue;
    }
    let (dir, name) = crate::map::split(&rel);
    if produced.get(dir).is_some_and(|names| names.contains(name)) {
        continue;
    }
    files.insert(rel);
}
````)

#chunk("status: group them by directory", ````rust
let mut found: BTreeMap<String, Vec<String>> = BTreeMap::new();
for entry in compress("", &files) {
    let (whole_directory, path) = match entry.strip_suffix('/') {
        Some(path) => (true, path),
        None => (false, entry.as_str()),
    };
    let (dir, name) = crate::map::split(path);
    let name = if whole_directory {
        format!("{name}/")
    } else {
        name.to_string()
    };
    found.entry(dir.to_string()).or_default().push(name);
}
````)

#chunk("status: sorted, and stable", ````rust
Ok(found
    .into_iter()
    .map(|(dir, mut entries)| {
        entries.sort();
        Unaccounted { dir, entries }
    })
    .collect())
````)

== What the tool itself writes

Three names, and only two of them are the tool's. The map records which declaration produced
each line; the directory the package is unpacked into holds two of the document's own `#file`
declarations in the form Typst wants to read them. Both are written by a pass of this program
under names nothing else uses, so both are accounted for by name: a map left behind in a
directory that stopped producing anything is that pass's to delete, and the package beside a
book is unpacked again every time the book is woven. Making a project declare its own tool's
scratch would be asking it to describe `lp` to `lp`.

The ignore file is not one of these. It is a *decision* — which files under the output
directory belong to somebody else — and a decision is either declared by the document, like any
other file, or written by a person, who then says so inside it. Exempting it by name is how a
`.lpignore` whose declaration went away stayed in the tree for good: nothing produced it,
nothing matched it, and nothing removed it, because the report had never seen it.

#chunk("status: what the tool writes is not content", ````rust
fn is_own_output(path: &Path) -> bool {
    path.file_name().is_some_and(|name| name == MAP_FILE)
}
````)

== A build directory is one line

One constant, and its value is a judgement: eight entries is where a list stops being readable
and naming the directory starts being more useful.

#chunk("status: when a subtree is too big to list", ````rust
const COMPRESS_ABOVE: usize = 8;
````)

#chunk("status: compressing a subtree", ````rust
fn compress(dir: &str, files: &BTreeSet<String>) -> Vec<String> {
    let prefix = if dir.is_empty() {
        String::new()
    } else {
        format!("{dir}/")
    };
    let mut entries: Vec<String> = files
        .iter()
        .filter(|file| file.starts_with(&prefix) && !file[prefix.len()..].contains('/'))
        .cloned()
        .collect();

    for sub in subdirectories(dir, files) {
        entries.extend(compress(&sub, files));
    }

    if !dir.is_empty() && entries.len() > COMPRESS_ABOVE {
        return vec![format!("{dir}/")];
    }
    entries
}
````)

The threshold is applied at the directory that actually overflows, and never to the output
directory itself: reporting `./` as one entry would tell the user nothing at all about
where to look.

#chunk("status: finding the subdirectories", ````rust
fn subdirectories(dir: &str, files: &BTreeSet<String>) -> BTreeSet<String> {
    let prefix = if dir.is_empty() {
        String::new()
    } else {
        format!("{dir}/")
    };
    files
        .iter()
        .filter_map(|file| {
            let rest = file.strip_prefix(&prefix)?;
            let (child, _) = rest.split_once('/')?;
            Some(format!("{prefix}{child}"))
        })
        .collect()
}
````)

== Removing, when the user asks for it

The only code in the program that removes anything, and the walk that tidies up the directories
it leaves empty behind it.

#chunk("status: delete, on request", ````rust
pub fn delete(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
) -> Result<Vec<String>, LpError> {
    let mut removed = Vec::new();
    for group in unaccounted(out, produced)? {
        for entry in group.entries {
            let whole_directory = entry.ends_with('/');
            let name = entry.trim_end_matches('/');
            let relative = crate::map::join(&group.dir, name);
            let path = out.join(&relative);
            if whole_directory {
                std::fs::remove_dir_all(&path).map_err(|err| LpError::io(&path, err))?;
            } else {
                std::fs::remove_file(&path).map_err(|err| LpError::io(&path, err))?;
            }
            prune_empty_dirs(path.parent().unwrap_or(out), out);
            removed.push(relative);
        }
    }
    Ok(removed)
}
````)

#chunk("status: cleaning up directories that emptied", ````rust
pub fn prune_empty_dirs(start: &Path, stop: &Path) {
    let mut dir = Some(start);
    while let Some(current) = dir {
        if current == stop || !current.starts_with(stop) {
            break;
        }
        let empty = std::fs::read_dir(current).is_ok_and(|mut entries| entries.next().is_none());
        if !empty || std::fs::remove_dir(current).is_err() {
            break;
        }
        dir = current.parent();
    }
}
````)

The upward walk stops at the output directory — never above it, and never removing the
output directory itself, which is the one thing a pass is allowed to consider its own
without asking.

== The report a person or a script reads

Four ways out, three of them 0. Two are a run that found nothing to complain about — nothing declared, or
everything accounted for — and saying so is not noise: that sentence is what makes silence from `--check`
meaningful, and the count of produced files is what makes it checkable at a glance.

#chunk("status: nothing was declared", ````rust
if produced.is_empty() {
    println!(
        "{}: the document declares no files, so lp writes nothing here and owns nothing",
        out.display()
    );
    return Ok(0);
}
````)

#chunk("status: everything is accounted for", ````rust
let unaccounted = unaccounted(out, produced)?;
if unaccounted.is_empty() {
    let accounted: usize = produced.values().map(BTreeSet::len).sum();
    println!(
        "{}: every file under the output directory is accounted for ({accounted} produced by chunks, the rest declared)",
        out.display()
    );
    return Ok(0);
}
````)

#chunk("status: delete, when that is what was asked", ````rust
if delete_unaccounted {
    for relative in delete(out, produced)? {
        println!("deleted {relative}");
    }
    return Ok(0);
}
````)

#chunk("status: list them, and say what to do", ````rust
for group in &unaccounted {
    let label = if group.dir.is_empty() {
        "."
    } else {
        group.dir.as_str()
    };
    println!("{label}/ — {} nothing accounts for:", group.entries.len());
    for entry in &group.entries {
        println!("  {}", crate::map::join(&group.dir, entry));
    }
}
println!();
println!(
    "Everything else under there is either produced by a chunk or declared in a .lpignore."
);
println!(
    "Each line above is one of: something a chunk should produce, something to declare in"
);
println!("that directory's .lpignore, or stale output to delete.");
println!("Nothing is removed on its own: declare it, or run `lp unaccounted --delete`.");
Ok(1)
````)

The exit status is 1 for the listing, so a caller — a CI step, a script, an agent — can tell
that case from a clean run without reading the text, and 0 for the two quiet outcomes and
for a deletion that succeeded.
