// The lp tool describing itself: the crate and the skill it ships, as declarations.
//
// `lp tangle lp.typ --out .` regenerates Cargo.toml, src/, tests/ and the skill;
// the repository is its own output (ADR D15). The declarations are a faithful
// transliteration of the frozen seed in seed/ — chunks are not shared here yet,
// and nothing is inlined, so the tangled files are byte-identical to the seed.
//
// Lines that look like references are escaped with `@` in the text below, because a
// document that quotes the syntax has to be able to show `<<name>>` on a line of its
// own without it being expanded (ADR D17).
//
// The seed, not this document, is what a broken toolchain falls back on:
//
//   nix develop -c cargo build --manifest-path seed/Cargo.toml
//   nix develop -c ./seed/target/debug/lp tangle lp.typ --out .
//
// Editing this file by hand is fine; running this script is not. It exists to record
// how Stage 1 was cut, not to be re-run over an edited document.

#import "lit/lp.typ": chunk, file, rule
#show: rule

= The tool, in its own words

Every file below is a root chunk. `seed/` holds the same bytes, frozen: the seed has
to stay compilable without the tool it ships.

#file("Cargo.toml", ````toml
[package]
name = "lp"
version = "0.1.0"
edition = "2024"
publish = false
description = "Typst-based literate programming: tangle source files out of a .typ document"

# The seed and the old probes are their own little worlds: nothing here depends on
# them, and saying so keeps the resolver out of their manifests.
[workspace]
exclude = ["seed", "agent-notes/experiments/*"]

[dependencies]
clap = { version = "4", features = ["derive"] }
ignore = "0.4.33"
miette = { version = "7", features = ["fancy"] }
notify = "8.2.0"
notify-debouncer-full = "0.7.0"
regex = "1"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
thiserror = "2"

[dev-dependencies]
tempfile = "3"
````)

#file("src/diag.rs", ````rust
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
````)

#file("src/explain.rs", ````rust
//! Turning a toolchain's diagnostics into chunk references.
//!
//! `lp explain` is a filter: it echoes what it reads and, for every
//! `file:line:col:` it can find in a map, prints which chunk that generated line
//! came from and how far into it the line is. Find that chunk in the document —
//! `rg '#chunk("print-results"'` — and you are at the place to edit.
//!
//! It knows nothing about any language, and it does not know `.typ` line numbers
//! either: Typst does not expose source positions (ADR D14).

use std::path::Path;

use regex::Regex;

use crate::diag::LpError;
use crate::map::{LpMap, join, resolve_all};

pub fn run(out: &Path, format: &str, input: &str) -> Result<usize, LpError> {
    if format == "cargo" {
        return Err(
            LpError::plain("--format cargo (JSON) is not implemented yet")
                .with_help("pipe `cargo build --message-format=short` through lp explain instead"),
        );
    }

    let pattern = Regex::new(r"^(?P<file>[^\s:]+\.\w+):(?P<line>\d+):(?P<col>\d+):\s?(?P<msg>.*)$")
        .map_err(|err| LpError::plain(format!("internal: bad diagnostic pattern: {err}")))?;

    let maps = LpMap::read_all(out);
    let mut mapped = 0;

    for line in input.lines() {
        println!("{line}");

        let Some(caps) = pattern.captures(line) else {
            continue;
        };
        let (file, out_line) = (&caps["file"], caps["line"].parse::<usize>().unwrap_or(0));
        let Ok((dir, name, entry)) = resolve_all(&maps, file) else {
            continue;
        };
        let Some((run, offset)) = entry.locate(out_line) else {
            continue;
        };
        let rel = join(dir, name);
        eprintln!(
            "  ↳ chunk ⟪{}⟫, line {offset} of it  ({rel}:{out_line})",
            run.chunk
        );
        mapped += 1;
    }

    Ok(mapped)
}
````)

#file("src/main.rs", ````rust
mod diag;
mod explain;
mod map;
mod metadata;
mod status;
mod tangle;
mod watch;

use std::collections::BTreeSet;
use std::io::Read;
use std::path::PathBuf;

use clap::{Parser, Subcommand};

use diag::LpError;

#[derive(Parser)]
#[command(name = "lp", version, about = "Typst-based literate programming")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Expand a .typ document into its source files
    Tangle {
        /// Documents to tangle, e.g. examples/demo/literate.typ
        #[arg(required = true)]
        docs: Vec<PathBuf>,
        /// Directory the root chunk names resolve into
        #[arg(long, default_value = "out")]
        out: PathBuf,
        /// Write nothing; fail if the generated files are out of date
        #[arg(long)]
        check: bool,
    },
    /// Tell which chunk produced a line of a generated file (or the reverse)
    Map {
        /// Generated file, relative to --out (a unique basename also works)
        #[arg(long, conflicts_with = "typ")]
        file: Option<String>,
        /// Reverse mode: list the generated lines that came from this chunk
        #[arg(long, conflicts_with = "file")]
        typ: Option<String>,
        /// Line of the generated file (required with --file)
        #[arg(long)]
        line: Option<usize>,
        #[arg(long, default_value = "out")]
        out: PathBuf,
    },
    /// Rewrite diagnostics so they name the chunk that produced the line
    Explain {
        #[arg(long, default_value = "out")]
        out: PathBuf,
        /// Diagnostic format on stdin
        #[arg(long, default_value = "generic", value_parser = ["generic", "cargo"])]
        format: String,
    },
    /// Keep the generated files in step while the document is edited
    Watch {
        /// Documents to watch, e.g. examples/demo/literate.typ
        #[arg(required = true)]
        docs: Vec<PathBuf>,
        #[arg(long, default_value = "out")]
        out: PathBuf,
        /// Coalesce editor events for this many milliseconds
        #[arg(long, default_value_t = 200)]
        debounce: u64,
        /// Command to run after a pass that changed something, e.g.
        /// 'cargo build --message-format=short'; its diagnostics get translated
        #[arg(long)]
        check_cmd: Option<String>,
    },
    /// List the chunks a document declares
    List { doc: PathBuf },
    /// Ask the documents which chunks they have, in order
    Metadata {
        /// Documents to ask, e.g. book.typ chapter.typ
        #[arg(required = true)]
        docs: Vec<PathBuf>,
    },
    /// List (or delete) files under the output directory that nothing accounts for
    Unaccounted {
        /// Documents that decide what counts as produced
        #[arg(required = true)]
        docs: Vec<PathBuf>,
        #[arg(long, default_value = "out")]
        out: PathBuf,
        /// Delete them: the explicit alternative to declaring them
        #[arg(long)]
        delete: bool,
    },
}

fn main() {
    let _ = miette::set_hook(Box::new(|_| {
        Box::new(miette::GraphicalReportHandler::new_themed(
            miette::GraphicalTheme::unicode(),
        ))
    }));
    match run() {
        Ok(code) => std::process::exit(code),
        Err(err) => {
            eprintln!("{:?}", miette::Report::new(err));
            std::process::exit(1);
        }
    }
}

fn run() -> Result<i32, LpError> {
    match Cli::parse().command {
        Command::Tangle { docs, out, check } => {
            let outcome = tangle::run(&docs, &out, check)?;
            for output in &outcome.changed {
                println!(
                    "wrote  {}  ({} lines, {})",
                    output.root,
                    output.lines,
                    output.lang.as_deref().unwrap_or("-")
                );
            }
            for output in &outcome.unchanged {
                println!("ok     {}", output.root);
            }
            for line in &outcome.stale {
                eprintln!("{line}");
            }
            for warning in &outcome.warnings {
                eprintln!("warning: {warning}");
            }
            for group in &outcome.unaccounted {
                let label = if group.dir.is_empty() {
                    "."
                } else {
                    group.dir.as_str()
                };
                eprintln!(
                    "note: {} entr{} in {label}/ that nothing accounts for (run `lp unaccounted`)",
                    group.entries.len(),
                    if group.entries.len() == 1 { "y" } else { "ies" }
                );
            }
            Ok(i32::from(!outcome.stale.is_empty()))
        }
        Command::Watch {
            docs,
            out,
            debounce,
            check_cmd,
        } => {
            watch::run(watch::Options {
                docs,
                out,
                debounce: std::time::Duration::from_millis(debounce),
                check_cmd,
            })?;
            Ok(0)
        }
        Command::Map {
            file,
            typ,
            line,
            out,
        } => {
            let maps = map::LpMap::read_all(&out);

            if let Some(chunk) = typ {
                // Reverse: which generated lines came from this chunk?
                let mut hits = 0;
                for (dir, map) in &maps {
                    for (name, file) in &map.files {
                        for run in &file.runs {
                            if run.chunk == chunk {
                                for line in run.first..=run.last {
                                    println!("{}:{}", map::join(dir, name), line);
                                    hits += 1;
                                }
                            }
                        }
                    }
                }
                if hits == 0 {
                    eprintln!("note: nothing in the generated files came from chunk ⟪{chunk}⟫");
                }
                return Ok(0);
            }

            let (Some(file), Some(line)) = (file, line) else {
                return Err(LpError::plain("lp map --file needs a --line").with_help(
                    "use `lp map --file src/main.rs --line 42` for a generated line, or `lp map --typ <chunk>` the other way",
                ));
            };
            let (dir, name, entry) = map::resolve_all(&maps, &file)?;
            let rel = map::join(dir, name);
            let Some((run, offset)) = entry.locate(line) else {
                return Err(LpError::plain(format!(
                    "{rel}:{line}: no map knows this file"
                )));
            };

            // Where to edit: the chunk, and how far into it this line is. Typst
            // exposes no source positions, so a name is the pointer (ADR D14).
            println!("chunk ⟪{}⟫, line {offset} of it", run.chunk);
            println!("    find it with: rg '#chunk(\"{}\")'", run.chunk);
            Ok(0)
        }
        Command::Explain { out, format } => {
            let mut input = String::new();
            std::io::stdin()
                .read_to_string(&mut input)
                .map_err(|e| LpError::plain(e.to_string()))?;
            let mapped = explain::run(&out, &format, &input)?;
            if mapped == 0 {
                eprintln!("note: no diagnostic line matched any map");
            }
            Ok(0)
        }
        Command::List { doc } => {
            list(std::slice::from_ref(&doc))?;
            Ok(0)
        }
        Command::Metadata { docs } => {
            let typst = metadata::binary()?;
            for declaration in metadata::declarations(&typst, &docs)? {
                println!(
                    "{:<6} {:<28} {:<8} {}",
                    declaration.lp,
                    declaration.name,
                    declaration.lang.as_deref().unwrap_or("-"),
                    declaration.text.lines().next().unwrap_or("")
                );
            }
            Ok(0)
        }
        Command::Unaccounted { docs, out, delete } => {
            let plan = tangle::plan(&docs)?;
            status::run(&out, &tangle::produced(&plan), delete)
        }
    }
}

fn list(docs: &[PathBuf]) -> Result<(), LpError> {
    let plan = tangle::plan(docs)?;
    let set = tangle::ChunkSet::new(&plan.blocks);
    let referenced: BTreeSet<String> = plan.blocks.iter().flat_map(tangle::refs_of).collect();

    for doc in docs {
        println!("{}", doc.display());
    }
    for block in &plan.blocks {
        let kind = if block.root { "file" } else { "frag" };
        let used = if referenced.contains(&block.name) || block.root {
            String::new()
        } else {
            "unreferenced".to_string()
        };
        println!(
            "  {kind}  {:<28} {:<8} {}",
            format!("⟪{}⟫", block.name),
            block.lang.as_deref().unwrap_or("-"),
            used
        );
    }

    let roots = set.roots();
    println!(
        "\noutputs: {}",
        if roots.is_empty() {
            "(none)".to_string()
        } else {
            roots
                .iter()
                .map(|root| format!("<{root}>"))
                .collect::<Vec<_>>()
                .join(", ")
        }
    );
    Ok(())
}
````)

#file("src/map.rs", ````rust
//! Which chunk produced which lines of a generated file.
//!
//! Not line numbers: Typst exposes no source positions, and recovering them would
//! mean searching the source or parsing Typst again — neither is worth doing for
//! a convenience (ADR D14). What expansion *does* know for free is which chunk
//! produced each run of output lines, and how far into that chunk the run starts.
//! That is what a map records, one per directory, next to the files it explains.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use ignore::WalkBuilder;
use serde::{Deserialize, Serialize};

use crate::diag::LpError;

pub const MAP_FILE: &str = ".lpmap.json";
const VERSION: u32 = 5;

#[derive(Debug, Serialize, Deserialize)]
pub struct LpMap {
    pub version: u32,
    /// Documents that produced the files listed here.
    pub docs: Vec<String>,
    /// Keyed by file name *within this directory*.
    pub files: BTreeMap<String, FileMap>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileMap {
    pub lang: Option<String>,
    /// Consecutive output lines that came from one chunk, in output order.
    pub runs: Vec<Run>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Run {
    pub chunk: String,
    /// 1-based first and last output line of the run.
    pub first: usize,
    pub last: usize,
}

impl Default for LpMap {
    fn default() -> Self {
        Self {
            version: VERSION,
            docs: Vec::new(),
            files: BTreeMap::new(),
        }
    }
}

impl LpMap {
    pub fn is_empty(&self) -> bool {
        self.files.is_empty()
    }

    pub fn set_docs(&mut self, docs: impl IntoIterator<Item = String>) {
        self.docs = docs
            .into_iter()
            .collect::<BTreeSet<_>>()
            .into_iter()
            .collect();
    }

    /// Write only when the serialized map actually differs, so a no-op pass leaves
    /// the mtime alone.
    pub fn write_if_changed(&self, dir: &Path) -> Result<bool, LpError> {
        let (path, json) = self.serialize(dir)?;
        if std::fs::read_to_string(&path).ok().as_deref() == Some(json.as_str()) {
            return Ok(false);
        }
        std::fs::write(&path, json).map_err(|err| LpError::io(&path, err))?;
        Ok(true)
    }

    pub fn read(dir: &Path) -> Result<Self, LpError> {
        let path = dir.join(MAP_FILE);
        let text = std::fs::read_to_string(&path).map_err(|err| LpError::io(&path, err))?;
        serde_json::from_str(&text)
            .map_err(|err| LpError::plain(format!("{}: {err}", path.display())))
    }

    /// Every map under `out`, paired with its directory relative to `out` (`""`
    /// for the output directory itself), in a stable order.
    pub fn read_all(out: &Path) -> Vec<(String, LpMap)> {
        if !out.exists() {
            return Vec::new();
        }

        let walker = WalkBuilder::new(out)
            .standard_filters(false)
            .hidden(false)
            .build();
        let mut found = Vec::new();
        for entry in walker.flatten() {
            if entry.file_name() != MAP_FILE {
                continue;
            }
            let Some(dir) = entry.path().parent() else {
                continue;
            };
            if let Ok(map) = Self::read(dir) {
                found.push((relative(out, dir), map));
            }
        }
        found.sort_by(|a, b| a.0.cmp(&b.0));
        found
    }

    fn serialize(&self, dir: &Path) -> Result<(PathBuf, String), LpError> {
        let path = dir.join(MAP_FILE);
        let json = serde_json::to_string_pretty(self)
            .map_err(|err| LpError::plain(format!("{}: {err}", path.display())))?;
        Ok((path, json + "\n"))
    }
}

impl FileMap {
    /// Which chunk produced this output line, and how far into it the line is
    /// (1-based). Falls back to the closest earlier run so blank lines still
    /// report something.
    pub fn locate(&self, line: usize) -> Option<(&Run, usize)> {
        let run = self
            .runs
            .iter()
            .find(|run| run.first <= line && line <= run.last)
            .or_else(|| self.runs.iter().rev().find(|run| run.first < line))?;
        Some((run, line.saturating_sub(run.first) + 1))
    }
}

/// Split an output path into `(directory, file name)`; the directory is `""` for
/// files directly in the output directory. Both use forward slashes.
pub fn split(rel: &str) -> (&str, &str) {
    match rel.rsplit_once('/') {
        Some((dir, name)) => (dir, name),
        None => ("", rel),
    }
}

pub fn join(dir: &str, name: &str) -> String {
    if dir.is_empty() {
        name.to_string()
    } else {
        format!("{dir}/{name}")
    }
}

/// Relative path with forward slashes.
pub fn relative(out: &Path, path: &Path) -> String {
    path.strip_prefix(out)
        .unwrap_or(path)
        .to_string_lossy()
        .replace('\\', "/")
}

/// Find the map that knows a file: every directory's map is consulted, and the
/// most specific one wins.
///
/// The path may be written relative to the output directory, to the working
/// directory, or absolutely — so the *directory* part of what a toolchain reported
/// is compared against each map's own directory, and only maps that are a suffix
/// of it (or the output directory itself) are considered. A bare file name with
/// several candidates is an error rather than a guess.
pub fn resolve_all<'a>(
    maps: &'a [(String, LpMap)],
    file: &str,
) -> Result<(&'a str, &'a str, &'a FileMap), LpError> {
    let normalized = file.replace('\\', "/");
    let (indir, name) = split(&normalized);

    let mut candidates: Vec<(&str, &str, &FileMap)> = Vec::new();
    for (dir, map) in maps {
        let Some((key, entry)) = map.files.get_key_value(name) else {
            continue;
        };
        let in_scope = indir.is_empty()
            || dir.is_empty()
            || indir == dir
            || indir.ends_with(&format!("/{dir}"));
        if in_scope {
            candidates.push((dir.as_str(), key.as_str(), entry));
        }
    }

    candidates.sort_by_key(|(dir, _, _)| std::cmp::Reverse(dir.len()));
    let Some(best) = candidates.first() else {
        let known = maps
            .iter()
            .flat_map(|(dir, map)| map.files.keys().map(move |name| join(dir, name)))
            .collect::<Vec<_>>()
            .join(", ");
        return Err(LpError::plain(format!("{file}: no map knows this file"))
            .with_help(format!("known files: {known}")));
    };
    if candidates
        .get(1)
        .is_some_and(|(dir, _, _)| dir.len() == best.0.len())
    {
        let all = candidates
            .iter()
            .map(|(dir, name, _)| join(dir, name))
            .collect::<Vec<_>>()
            .join(", ");
        return Err(
            LpError::plain(format!("{file}: which map?")).with_help(format!("candidates: {all}"))
        );
    }
    Ok(*best)
}
````)

#file("src/metadata.rs", ````rust
//! What the document declares its chunks to be.
//!
//! Typst is Turing-complete: a chunk can come from a loop, a branch, a function
//! or an `#include`d file, so the only authority is evaluation. The document
//! declares its chunks through the `lp` package (`lit/lp.typ`), whose `chunk` and
//! `file` functions take the code block as an argument and emit one metadata
//! record each:
//!
//! ```typ
//! #chunk("imports", ```rust
//! use std::fmt;
//! ```)
//!
//! #file("src/main.rs", ```rust
//! <<imports>>
//! ```)
//! ```
//!
//! A declaration carries name, language and text, so nothing has to be recovered
//! from the source afterwards — which is why the sources are not read at all.

use std::path::{Path, PathBuf};
use std::process::Command;

use serde::Deserialize;

use crate::diag::LpError;

/// Every declaration, in the order the document produced them.
const QUERY: &str = "query(<lp-decl>).map(declaration => declaration.value)";

#[derive(Debug, Clone, Deserialize)]
pub struct Decl {
    /// `"chunk"` or `"file"`.
    pub lp: String,
    /// The fragment's name, or the path for a file declaration.
    pub name: String,
    #[serde(default)]
    pub lang: Option<String>,
    #[serde(default)]
    pub text: String,
}

/// What the two declaration functions mean.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    /// `#chunk(name, …)`: a fragment that only exists where it is referenced.
    Chunk,
    /// `#file(path, …)`: a chunk whose name is the path it is written to.
    File,
}

impl Decl {
    /// A declaration that says something else is a mistake in the package or in
    /// whatever emitted the metadata — not a fragment by default.
    pub fn kind(&self) -> Result<Kind, LpError> {
        match self.lp.as_str() {
            "chunk" => Ok(Kind::Chunk),
            "file" => Ok(Kind::File),
            other => Err(LpError::plain(format!(
                "{}: unknown declaration kind {other:?}",
                self.name
            ))
            .with_help("the package emits `lp: \"chunk\"` or `lp: \"file\"`")),
        }
    }
}

/// Locate the `typst` binary: an explicit override, then `PATH`.
pub fn binary() -> Result<PathBuf, LpError> {
    if let Some(path) = std::env::var_os("LP_TYPST") {
        return Ok(PathBuf::from(path));
    }
    let name = if cfg!(windows) { "typst.exe" } else { "typst" };
    std::env::var_os("PATH")
        .and_then(|paths| std::env::split_paths(&paths).map(|dir| dir.join(name)).find(|candidate| candidate.is_file()))
        .ok_or_else(|| {
            LpError::plain("no `typst` binary found").with_help(
                "tangling asks the document for its declarations, so typst has to be available (set LP_TYPST or put it on PATH)",
            )
        })
}

/// Evaluate the documents and read their declarations.
///
/// Typst resolves `#include` against its project root, which is the directory of
/// the file being evaluated. So the wrapper is written where every document lives
/// and includes them relatively: a document outside the working directory works
/// the same as one inside it. (Writing the wrapper into the working directory, as
/// this did at first, silently refused any document that was not under it.)
pub fn declarations(typst: &Path, docs: &[PathBuf]) -> Result<Vec<Decl>, LpError> {
    let cwd = std::env::current_dir()
        .map_err(|err| LpError::plain(format!("cannot read the working directory: {err}")))?;
    let docs: Vec<PathBuf> = docs
        .iter()
        .map(|doc| std::path::absolute(doc).unwrap_or_else(|_| cwd.join(doc)))
        .collect();

    // Typst refuses to read outside its project root, and a document may import a
    // package from outside its own directory, so the root has to cover the working
    // directory *and* every document. The wrapper lives next to the documents (it
    // must be inside the root to be readable) and includes them relatively.
    let root = common_ancestor(
        &[cwd.clone()]
            .into_iter()
            .chain(docs.iter().cloned())
            .collect::<Vec<_>>(),
    );
    let wrapper = Wrapper::write(&common_ancestor(&docs), &docs)?;
    let output = Command::new(typst)
        .arg("eval")
        .arg(QUERY)
        .arg("--in")
        .arg(&wrapper.path)
        .arg("--root")
        .arg(&root)
        .current_dir(&cwd)
        .output();
    drop(wrapper);

    let output =
        output.map_err(|err| LpError::plain(format!("cannot run {}: {err}", typst.display())))?;
    if !output.status.success() {
        let message = String::from_utf8_lossy(&output.stderr);
        return Err(LpError::plain(format!(
            "the document did not evaluate, so there are no chunks to tangle:\n{}",
            message.trim_end()
        )));
    }

    let declarations: Vec<Decl> = serde_json::from_slice(&output.stdout).map_err(|err| {
        LpError::plain(format!("cannot read the document's declarations: {err}"))
            .with_help(String::from_utf8_lossy(&output.stdout).to_string())
    })?;
    if declarations.is_empty() {
        return Err(LpError::plain("the document declares no chunks").with_help(
            "import the package and declare them: `#import \"lp.typ\": chunk, file`, then `#chunk(\"name\", ```…```)` or `#file(\"src/main.rs\", ```…```)`",
        ));
    }
    for declaration in &declarations {
        declaration.kind()?;
    }
    Ok(declarations)
}

/// A wrapper document, removed when it goes out of scope — including when the
/// evaluation fails, and including on panic.
struct Wrapper {
    path: PathBuf,
}

impl Wrapper {
    fn write(root: &Path, docs: &[PathBuf]) -> Result<Self, LpError> {
        let path = root.join(format!(".lp-decl-{}.typ", std::process::id()));
        let mut text = String::new();
        for doc in docs {
            let relative = doc.strip_prefix(root).unwrap_or(doc);
            // Quoted, because that is how Typst takes a path; a quote or backslash
            // in a file name must not break the wrapper open.
            let quoted = relative
                .to_string_lossy()
                .replace('\\', "/")
                .replace('"', "\\\"");
            text.push_str(&format!("#include \"{quoted}\"\n"));
        }
        std::fs::write(&path, text).map_err(|err| LpError::io(&path, err))?;
        Ok(Self { path })
    }
}

impl Drop for Wrapper {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}

/// The deepest directory that contains every document.
fn common_ancestor(docs: &[PathBuf]) -> PathBuf {
    let mut root = docs
        .first()
        .and_then(|doc| doc.parent())
        .map(Path::to_path_buf)
        .unwrap_or_else(|| PathBuf::from("/"));

    for doc in docs.iter().skip(1) {
        while !doc.starts_with(&root) {
            match root.parent() {
                Some(parent) => root = parent.to_path_buf(),
                None => return root,
            }
        }
    }
    root
}

#[cfg(test)]
mod tests {
    use super::common_ancestor;
    use std::path::{Path, PathBuf};

    #[test]
    fn the_wrapper_goes_where_every_document_lives() {
        assert_eq!(
            common_ancestor(&[
                PathBuf::from("/a/b/book.typ"),
                PathBuf::from("/a/b/chapter.typ")
            ]),
            Path::new("/a/b")
        );
        assert_eq!(
            common_ancestor(&[
                PathBuf::from("/a/book.typ"),
                PathBuf::from("/a/c/chapter.typ")
            ]),
            Path::new("/a")
        );
        assert_eq!(
            common_ancestor(&[PathBuf::from("/a/book.typ")]),
            Path::new("/a")
        );
    }
}
````)

#file("src/status.rs", ````rust
//! What nothing accounts for.
//!
//! Every file under the output directory falls into exactly one of three groups:
//!
//! * **produced** — a `#file` declaration writes it;
//! * **declared** — a `.lpignore` says *"lp does not manage this"*;
//! * **unaccounted** — neither. Nothing explains why it is there.
//!
//! The third group is the one worth reporting: a file a chunk should probably
//! produce, a file to declare, or stale output to delete — and only the user knows
//! which. Nothing here deletes anything; `delete` is called from
//! `lp unaccounted --delete` and never as a side effect of tangling.
//!
//! Point `--out` at a directory and the whole directory is `lp`'s, at any depth.
//! The `.lpignore` rules say what is not, and the crate's own walker applies them
//! — nested files, deepest wins, whitelists — so there is no second
//! implementation of that logic here.

use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

use ignore::WalkBuilder;

use crate::diag::LpError;
use crate::map::{MAP_FILE, relative};

/// The file in which a directory declares what `lp` does not manage.
pub const IGNORE_FILE: &str = ".lpignore";

/// Entries in one directory that nothing accounts for.
#[derive(Debug)]
pub struct Unaccounted {
    /// Directory relative to the output directory (`""` for the output itself).
    pub dir: String,
    /// File or directory names, a directory marked with a trailing `/`.
    pub entries: Vec<String>,
}

/// Everything under the output directory that no chunk produces and no
/// declaration owns.
pub fn unaccounted(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
) -> Result<Vec<Unaccounted>, LpError> {
    if produced.is_empty() || !out.exists() {
        return Ok(Vec::new());
    }

    // What the walker yields is content: it applies every `.lpignore` in the tree
    // as it descends, so a declared file — or a whole declared directory — never
    // reaches this loop.
    let mut builder = WalkBuilder::new(out);
    builder
        .standard_filters(false)
        .hidden(false)
        .parents(false)
        .add_custom_ignore_filename(IGNORE_FILE);

    let mut files: BTreeSet<String> = BTreeSet::new();
    for entry in builder.build() {
        let entry =
            entry.map_err(|err| LpError::plain(format!("cannot scan {}: {err}", out.display())))?;
        if !entry.file_type().is_some_and(|kind| kind.is_file()) {
            continue;
        }
        let path = entry.path();
        if is_control_file(path) {
            continue;
        }
        let rel = relative(out, path);
        let (dir, name) = crate::map::split(&rel);
        if produced.get(dir).is_some_and(|names| names.contains(name)) {
            continue;
        }
        files.insert(rel);
    }

    let mut found: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for entry in compress("", &files) {
        // A compressed entry keeps its trailing slash so a reader can tell a
        // directory from a file.
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
    Ok(found
        .into_iter()
        .map(|(dir, mut entries)| {
            entries.sort();
            Unaccounted { dir, entries }
        })
        .collect())
}

/// `lp`'s own control files are never content.
fn is_control_file(path: &Path) -> bool {
    path.file_name()
        .is_some_and(|name| name == MAP_FILE || name == IGNORE_FILE)
}

/// Beyond this many entries a subtree stops being listed file by file and is
/// named as a directory instead: a build directory is one line, not thousands.
const COMPRESS_ABOVE: usize = 8;

/// Turn the unaccounted files into the entries to show, compressing a directory
/// that carries too many of them.
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

/// Delete everything nothing accounts for.
///
/// This is the only way `lp` ever removes a file, and it never happens as a side
/// effect of tangling: stale output is either declared (then it is accounted for)
/// or deleted on request.
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

pub fn run(
    out: &Path,
    produced: &BTreeMap<String, BTreeSet<String>>,
    delete_unaccounted: bool,
) -> Result<i32, LpError> {
    if produced.is_empty() {
        println!(
            "{}: the document declares no files, so lp writes nothing here and owns nothing",
            out.display()
        );
        return Ok(0);
    }

    let unaccounted = unaccounted(out, produced)?;
    if unaccounted.is_empty() {
        let accounted: usize = produced.values().map(BTreeSet::len).sum();
        println!(
            "{}: every file under the output directory is accounted for ({accounted} produced by chunks, the rest declared)",
            out.display()
        );
        return Ok(0);
    }

    if delete_unaccounted {
        for relative in delete(out, produced)? {
            println!("deleted {relative}");
        }
        return Ok(0);
    }

    for group in &unaccounted {
        let label = if group.dir.is_empty() {
            "."
        } else {
            group.dir.as_str()
        };
        println!("{label}/ — {} nothing accounts for:", group.entries.len());
        for entry in &group.entries {
            // The full path, so a line here can be copied, grepped, or declared
            // as it stands.
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
}

#[cfg(test)]
mod tests {
    use super::unaccounted;
    use std::collections::{BTreeMap, BTreeSet};
    use std::fs;
    use tempfile::TempDir;

    fn write(path: &std::path::Path, contents: &str) {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).unwrap();
        }
        fs::write(path, contents).unwrap();
    }

    fn names(dir: &str, list: &[&str]) -> (String, BTreeSet<String>) {
        (
            dir.to_string(),
            list.iter().map(|name| name.to_string()).collect(),
        )
    }

    #[test]
    fn only_files_nothing_accounts_for_are_reported() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join(".lpignore"), "declared.txt\n");
        write(&out.join("produced.txt"), "chunk output");
        write(&out.join("declared.txt"), "mine, not lp's");
        write(&out.join("stray.txt"), "who put this here");
        write(&out.join("stray-dir/inside.txt"), "and this");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt"])].into_iter().collect();
        let found = unaccounted(out, &produced).unwrap();

        let listed: Vec<String> = found
            .iter()
            .flat_map(|group| {
                group
                    .entries
                    .iter()
                    .map(|entry| crate::map::join(&group.dir, entry))
                    .collect::<Vec<_>>()
            })
            .collect();
        let mut listed = listed;
        listed.sort();
        assert_eq!(
            listed,
            vec!["stray-dir/inside.txt".to_string(), "stray.txt".to_string()]
        );
    }

    #[test]
    fn a_directory_holding_only_declared_files_is_accounted_for() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join(".lpignore"), "**/*.log\n");
        write(&out.join("produced.txt"), "chunk output");
        write(&out.join("deep/nested/app.log"), "declared");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt"])].into_iter().collect();
        assert!(unaccounted(out, &produced).unwrap().is_empty());
    }

    #[test]
    fn a_large_unaccounted_subtree_is_named_once() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join("produced.txt"), "chunk output");
        for i in 0..20 {
            write(&out.join(format!("vendor/nested/file{i}.txt")), "x");
        }

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("", &["produced.txt"])].into_iter().collect();
        let found = unaccounted(out, &produced).unwrap();
        assert_eq!(found.len(), 1, "{found:?}");
        assert_eq!(found[0].dir, "vendor");
        assert_eq!(
            found[0].entries,
            vec!["nested/".to_string()],
            "one line, not twenty — the directory that actually overflows"
        );
    }

    #[test]
    fn the_output_directory_is_ours_all_the_way_down() {
        let dir = TempDir::new().unwrap();
        let out = dir.path();
        write(&out.join("src/produced.rs"), "chunk output");
        write(&out.join("src/next-to-it.rs"), "stray");
        write(&out.join("elsewhere/deep/a.txt"), "x");

        let produced: BTreeMap<String, BTreeSet<String>> =
            [names("src", &["produced.rs"])].into_iter().collect();
        let found = unaccounted(out, &produced).unwrap();
        let listed: Vec<String> = found
            .iter()
            .flat_map(|group| {
                group
                    .entries
                    .iter()
                    .map(|entry| crate::map::join(&group.dir, entry))
                    .collect::<Vec<_>>()
            })
            .collect();
        assert_eq!(
            listed,
            vec![
                "elsewhere/deep/a.txt".to_string(),
                "src/next-to-it.rs".to_string()
            ],
            "anything under the output directory, at any depth"
        );
    }
}
````)

#file("src/tangle.rs", ````rust
//! Tangling: expand chunks into whole files, write them, and record where every
//! output line came from.
//!
//! Which chunks exist is Typst's answer (`metadata.rs`), and it is the only thing
//! the tool cannot work out for itself. What is left here is our own small part:
//! `<<references>>`, indentation, writing files, and recording which chunk
//! produced which output lines.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use crate::diag::LpError;
use crate::map::{FileMap, LpMap, MAP_FILE, Run, split};
use crate::metadata;

/// A chunk as the document declared it.
pub struct Block {
    /// A `file` declaration names the path it is tangled to; a `chunk` is a
    /// fragment that only exists where it is referenced.
    pub root: bool,
    pub name: String,
    pub lang: Option<String>,
    pub text: String,
}

impl Block {
    /// An error about the `index`-th line of this chunk. It quotes the line: with
    /// no source positions to point at, the quote is what tells the reader where
    /// to look (ADR D14).
    fn error(&self, index: usize, message: impl Into<String>) -> LpError {
        let line = self.text.lines().nth(index).unwrap_or("");
        LpError::plain(format!("{}: {line}", message.into())).with_help(format!(
            "in chunk ⟪{}⟫, line {} of it",
            self.name,
            index + 1
        ))
    }
}

pub struct ChunkSet<'a> {
    chunks: BTreeMap<&'a str, Vec<&'a Block>>,
}

impl<'a> ChunkSet<'a> {
    /// One set over every chunk of the invocation, in the order the document
    /// produced them.
    pub fn new(blocks: &'a [Block]) -> Self {
        let mut chunks: BTreeMap<&str, Vec<&Block>> = BTreeMap::new();
        for block in blocks {
            chunks.entry(block.name.as_str()).or_default().push(block);
        }
        Self { chunks }
    }

    /// The declared files, in the order the document declared them.
    pub fn roots(&self) -> Vec<&'a str> {
        let mut roots: Vec<&str> = Vec::new();
        for blocks in self.chunks.values() {
            if let Some(block) = blocks.first()
                && block.root
                && !roots.contains(&block.name.as_str())
            {
                roots.push(block.name.as_str());
            }
        }
        roots
    }

    pub fn names(&self) -> impl Iterator<Item = &'a str> {
        self.chunks.keys().copied()
    }

    pub fn get(&self, name: &str) -> Option<&[&'a Block]> {
        self.chunks.get(name).map(Vec::as_slice)
    }
}

/// Reject declared paths that would write outside the output directory.
pub fn check_output_path(name: &str) -> Result<(), LpError> {
    let unsafe_name = name.is_empty()
        || name.starts_with('/')
        || name.contains('\\')
        || Path::new(name).components().any(|component| {
            matches!(
                component,
                std::path::Component::ParentDir
                    | std::path::Component::RootDir
                    | std::path::Component::Prefix(_)
            )
        });

    if unsafe_name {
        return Err(LpError::plain(format!("unsafe chunk name {name:?}"))
            .with_help("a file declaration must be a relative path inside --out, without `..`"));
    }
    Ok(())
}

/// `<<name>>` on a line of its own, with any indentation. Anything else on the
/// line (prose, `a << b` in C++) stays literal.
fn ref_target(line: &str) -> Option<(&str, &str)> {
    let trimmed = line.trim();
    let inner = trimmed.strip_prefix("<<")?.strip_suffix(">>")?;
    if inner.is_empty() || inner.contains('<') || inner.contains('>') {
        return None;
    }
    Some((inner, &line[..line.len() - line.trim_start().len()]))
}

/// A line that reads as a reference but has to stay literal: `@<<name>>` comes out
/// as `<<name>>`. A document quoting the syntax itself — this project's own skill,
/// for one — needs it (ADR D17).
fn escaped_ref(line: &str) -> Option<String> {
    let indent = &line[..line.len() - line.trim_start().len()];
    let rest = line.trim().strip_prefix('@')?;
    let inner = rest.strip_prefix("<<")?.strip_suffix(">>")?;
    if inner.is_empty() || inner.contains('<') || inner.contains('>') {
        return None;
    }
    Some(format!("{indent}<<{inner}>>"))
}

pub struct Tangled {
    /// File contents, always ending in a newline.
    pub text: String,
    /// Which chunk produced which consecutive output lines.
    pub runs: Vec<Run>,
    /// Lines written so far, so a run can be extended without counting the text.
    lines: usize,
}

impl Tangled {
    fn push(&mut self, chunk: &str, indent: &str, line: &str) {
        self.text.push_str(indent);
        self.text.push_str(line);
        self.text.push('\n');
        self.lines += 1;
        match self.runs.last_mut() {
            Some(run) if run.chunk == chunk && run.last + 1 == self.lines => run.last = self.lines,
            _ => self.runs.push(Run {
                chunk: chunk.to_string(),
                first: self.lines,
                last: self.lines,
            }),
        }
    }
}

pub fn expand(set: &ChunkSet, root: &str) -> Result<Tangled, LpError> {
    let mut out = Tangled {
        text: String::new(),
        runs: Vec::new(),
        lines: 0,
    };
    let mut stack = Vec::new();
    expand_chunk(set, root, "", &mut stack, &mut out)?;
    Ok(out)
}

fn expand_chunk(
    set: &ChunkSet,
    name: &str,
    indent: &str,
    stack: &mut Vec<String>,
    out: &mut Tangled,
) -> Result<(), LpError> {
    if let Some(start) = stack.iter().position(|entry| entry == name) {
        let mut chain: Vec<String> = stack[start..].to_vec();
        chain.push(name.to_string());
        let message = format!("cycle in chunks: {}", chain.join(" -> "));
        let block = set.get(name).and_then(|blocks| blocks.first()).copied();
        return Err(match block {
            Some(block) => block.error(0, message),
            None => LpError::plain(message),
        });
    }
    stack.push(name.to_string());

    for block in set.get(name).unwrap_or(&[]) {
        if block.text.trim().is_empty() {
            stack.pop();
            return Err(LpError::plain(format!("chunk ⟪{name}⟫ is empty"))
                .with_help("delete the declaration, or give it a code block with a body"));
        }

        for (index, line) in block.text.lines().enumerate() {
            if let Some(literal) = escaped_ref(line) {
                out.push(name, indent, &literal);
                continue;
            }
            match ref_target(line) {
                None => out.push(name, indent, line),
                Some((target, local_indent)) => {
                    if set.get(target).is_none() {
                        return Err(block
                            .error(index, format!("chunk ⟪{target}⟫ is not defined"))
                            .with_help(format!(
                                "referenced from ⟪{name}⟫; known chunks: {}",
                                set.names().collect::<Vec<_>>().join(", ")
                            )));
                    }
                    let nested = format!("{indent}{local_indent}");
                    expand_chunk(set, target, &nested, stack, out)?;
                }
            }
        }
    }

    stack.pop();
    Ok(())
}

#[derive(Debug)]
pub struct Output {
    pub root: String,
    pub lines: usize,
    pub lang: Option<String>,
}

#[derive(Debug, Default)]
pub struct Outcome {
    /// Outputs whose bytes differ from what is on disk (written unless checking).
    pub changed: Vec<Output>,
    /// Outputs that were already up to date.
    pub unchanged: Vec<Output>,
    /// Drift reports, filled only when `check` is set.
    pub stale: Vec<String>,
    /// Files under the output directory that neither a chunk nor a declaration
    /// accounts for. Non-empty means the pass failed.
    pub unaccounted: Vec<crate::status::Unaccounted>,
    pub warnings: Vec<String>,
}

/// What the documents produce, without writing anything.
pub struct Plan {
    pub maps: BTreeMap<PathBuf, LpMap>,
    pub texts: BTreeMap<String, String>,
    pub warnings: Vec<String>,
    pub blocks: Vec<Block>,
}

pub fn plan(docs: &[PathBuf]) -> Result<Plan, LpError> {
    let typst = metadata::binary()?;
    let blocks: Vec<Block> = metadata::declarations(&typst, docs)?
        .into_iter()
        .map(|declaration| Block {
            root: declaration.kind().expect("checked") == metadata::Kind::File,
            name: declaration.name,
            lang: declaration.lang,
            text: declaration.text,
        })
        .collect();

    let set = ChunkSet::new(&blocks);
    if set.roots().is_empty() {
        let listed = docs
            .iter()
            .map(|doc| doc.display().to_string())
            .collect::<Vec<_>>()
            .join(", ");
        return Err(LpError::plain(format!("no file declarations in {listed}"))
            .with_help("declare one: `#file(\"src/main.rs\", ```…```)`"));
    }

    let mut warnings = Vec::new();
    let referenced: BTreeSet<String> = blocks.iter().flat_map(refs_of).collect();
    let file_names: BTreeSet<&str> = blocks
        .iter()
        .filter(|block| block.root)
        .map(|block| block.name.as_str())
        .collect();
    for name in set.names() {
        if !file_names.contains(name) && !referenced.contains(name) {
            warnings.push(format!("chunk ⟪{name}⟫ is never referenced"));
        }
    }

    let mut maps: BTreeMap<PathBuf, LpMap> = BTreeMap::new();
    let mut texts: BTreeMap<String, String> = BTreeMap::new();
    let mut produced: BTreeSet<String> = BTreeSet::new();
    for root in set.roots() {
        check_output_path(root)?;
        let lang = set
            .get(root)
            .and_then(|blocks| blocks.first())
            .and_then(|block| block.lang.clone());
        let tangled = expand(&set, root)?;

        if !produced.insert(root.to_string()) {
            return Err(LpError::plain(format!("output {root} is produced twice")));
        }

        let entry = FileMap {
            lang,
            runs: tangled.runs,
        };
        let (dir, name) = split(root);
        maps.entry(PathBuf::from(dir))
            .or_default()
            .files
            .insert(name.to_string(), entry);
        texts.insert(root.to_string(), tangled.text);
    }

    Ok(Plan {
        maps,
        texts,
        warnings,
        blocks,
    })
}

/// What the documents produce, per directory: what `status.rs` counts against.
pub fn produced(plan: &Plan) -> BTreeMap<String, BTreeSet<String>> {
    plan.maps
        .iter()
        .map(|(dir, map)| {
            (
                dir.to_string_lossy().replace('\\', "/"),
                map.files.keys().cloned().collect(),
            )
        })
        .collect()
}

pub fn run(docs: &[PathBuf], out: &Path, check: bool) -> Result<Outcome, LpError> {
    let plan = plan(docs)?;
    let documented = docs
        .iter()
        .map(|doc| doc.display().to_string())
        .collect::<Vec<_>>();
    let mut outcome = Outcome {
        warnings: plan.warnings.clone(),
        ..Outcome::default()
    };

    for (root, text) in &plan.texts {
        let (dir, name) = split(root);
        let entry = &plan.maps[Path::new(dir)].files[name];
        let dest = out.join(root);
        let existing = std::fs::read_to_string(&dest).ok();
        let output = Output {
            root: root.clone(),
            lines: text.lines().count(),
            lang: entry.lang.clone(),
        };

        if existing.as_deref() == Some(text.as_str()) {
            outcome.unchanged.push(output);
        } else if check {
            outcome
                .stale
                .push(drift_report(root, existing.as_deref(), &entry.runs, text));
        } else {
            if let Some(parent) = dest.parent() {
                std::fs::create_dir_all(parent).map_err(|err| LpError::io(parent, err))?;
            }
            std::fs::write(&dest, text).map_err(|err| LpError::io(&dest, err))?;
            outcome.changed.push(output);
        }
    }

    // A map tracks the *document*, so it can be stale even when no output byte
    // moved (a line of prose shifts every mapping); `write_if_changed` compares
    // content rather than the output files'. Maps for directories that stopped
    // producing anything are removed with the directories themselves: the map
    // travels with the files it explains.
    //
    // The ownership check comes first: it runs before any map is written, but *after*
    // the files above, because `.lpignore` is one of the things a document can produce.
    // A fresh repository has no control file yet, and the pass that writes it is the
    // pass that makes the tree consistent (ADR D20).
    outcome.unaccounted = crate::status::unaccounted(out, &produced(&plan))?;
    if !outcome.unaccounted.is_empty() {
        let listed = outcome
            .unaccounted
            .iter()
            .flat_map(|group| {
                let label = if group.dir.is_empty() {
                    ".".to_string()
                } else {
                    group.dir.clone()
                };
                group
                    .entries
                    .iter()
                    .map(move |entry| format!("  {label}/{entry}"))
            })
            .collect::<Vec<_>>()
            .join("\n");
        return Err(LpError::plain(format!("nothing accounts for these files:\n{listed}")).with_help(
            "declare each one in the .lpignore of its directory, or delete it with `lp unaccounted --delete`",
        ));
    }

    if !check {
        let mut live: BTreeSet<String> = BTreeSet::new();
        for (dir, mut map) in plan.maps {
            if map.is_empty() {
                continue;
            }
            let dir = dir.to_string_lossy().replace('\\', "/");
            map.set_docs(documented.clone());
            map.write_if_changed(&out.join(&dir))?;
            live.insert(dir);
        }
        for (dir, _) in LpMap::read_all(out) {
            if live.contains(&dir) {
                continue;
            }
            let stale = out.join(&dir).join(MAP_FILE);
            if std::fs::remove_file(&stale).is_ok() {
                crate::status::prune_empty_dirs(stale.parent().unwrap_or(out), out);
            }
        }
    }
    Ok(outcome)
}

/// Every name referenced by a block, in document order.
pub fn refs_of(block: &Block) -> Vec<String> {
    let mut names = Vec::new();
    for line in block.text.lines() {
        if let Some((target, _)) = ref_target(line) {
            names.push(target.to_string());
        }
    }
    names
}

fn first_difference(old: Option<&str>, new: &str) -> Option<usize> {
    let old = old?;
    let old_lines: Vec<&str> = old.lines().collect();
    let new_lines: Vec<&str> = new.lines().collect();
    (0..old_lines.len().max(new_lines.len()))
        .find(|&index| old_lines.get(index) != new_lines.get(index))
        .map(|index| index + 1)
}

fn drift_report(root: &str, existing: Option<&str>, runs: &[Run], text: &str) -> String {
    match first_difference(existing, text) {
        Some(line) => {
            let origin = runs.iter().rev().find(|run| run.first <= line);
            match origin {
                Some(run) => format!("STALE  {root} (line {line}, in chunk ⟪{}⟫)", run.chunk),
                None => format!("STALE  {root} (line {line})"),
            }
        }
        None => format!("STALE  {root} (file missing)"),
    }
}

#[cfg(test)]
mod tests {
    use super::{escaped_ref, ref_target};

    #[test]
    fn only_a_whole_line_reference_counts() {
        assert_eq!(ref_target("<<body>>"), Some(("body", "")));
        assert_eq!(ref_target("    <<body>>  "), Some(("body", "    ")));
        // Not references: they must survive tangling as literal text.
        assert_eq!(ref_target("std::cout << x << std::endl;"), None);
        assert_eq!(ref_target("<<a>><<b>>"), None);
        assert_eq!(ref_target("auto y = <<x>>;"), None);
    }

    #[test]
    fn an_escaped_reference_comes_out_without_the_escape() {
        assert_eq!(escaped_ref("@<<body>>").as_deref(), Some("<<body>>"));
        assert_eq!(escaped_ref("  @<<body>>").as_deref(), Some("  <<body>>"));
        assert_eq!(escaped_ref("<<body>>"), None);
        assert_eq!(escaped_ref("@<<a>><<b>>"), None);
        assert_eq!(escaped_ref("@@<<body>>"), None);
    }
}
````)

#file("src/watch.rs", ````rust
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

    let outcome = match tangle::run(&options.docs, &options.out, false) {
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
    let dormant = outcome.changed.is_empty();

    if dormant {
        if initial {
            eprintln!(
                "sync   up to date ({} files, {ms:.1}ms)",
                outcome.unchanged.len()
            );
        }
        return false;
    }

    // Report even when nothing was written: deleting a root chunk leaves a file
    // behind without changing any other output.
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

    // Same translation as `lp explain`, reading the maps we just wrote.
    let _ = crate::explain::run(&options.out, "generic", &text);
}

fn report(err: LpError) {
    eprintln!("{:?}", miette::Report::new(err));
}
````)

#file("tests/flow.rs", ````rust
//! End-to-end tests: they run the real binary against throwaway documents.

use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../lit/lp.typ");

/// A document in the real authoring form: the package is imported, its rules are
/// installed, and the body declares chunks.
fn document(body: &str) -> String {
    format!("#import \"lp.typ\": chunk, file, rule\n#show: rule\n{body}")
}

/// One file declaration, a shared fragment, a fragment written in two pieces,
/// and a code sample that is not a chunk at all.
///
/// The two references are spliced in rather than written on lines of their own:
/// a line that is exactly `<<name>>` would be expanded when this file is tangled
/// (ADR D15, `agent-notes/decisions/2026-09-11-self-hosting-layout.md`).
const DOC: &str = concat!(
    "\
= Demo

#file(\"main.py\", ```py
",
    "<<imports>>\n",
    "<<body>>\n",
    "\
```)

#chunk(\"imports\", ```py
import sys
```)

#chunk(\"body\", ```py
print('one')
```)

#chunk(\"body\", ```py
print('two')
```)

```text
not a chunk
```
",
);

fn lp(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(args)
        .current_dir(dir)
        .output()
        .expect("run lp")
}

fn write_doc(dir: &Path, name: &str, body: &str) -> String {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    let text = document(body);
    std::fs::write(dir.join(name), &text).expect("doc");
    text
}

fn project(body: &str) -> (TempDir, std::path::PathBuf, String) {
    let dir = TempDir::new().expect("temp dir");
    let text = write_doc(dir.path(), "demo.typ", body);
    let path = dir.path().to_path_buf();
    (dir, path, text)
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).to_string()
}

fn line_of(text: &str, needle: &str) -> usize {
    text.lines()
        .position(|line| line.contains(needle))
        .expect("needle")
        + 1
}

#[test]
fn tangle_writes_files_with_concat_and_indentation() {
    let (_guard, dir, _) = project(DOC);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main.py"),
        "import sys\nprint('one')\nprint('two')\n"
    );
}

#[test]
fn tangle_records_which_chunk_every_line_came_from() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let map: serde_json::Value =
        serde_json::from_str(&std::fs::read_to_string(dir.join("out/.lpmap.json")).expect("map"))
            .expect("json");
    let entry = &map["files"]["main.py"];
    // No source positions anywhere: a run says which chunk, and which lines it covers.
    assert_eq!(
        entry["runs"],
        serde_json::json!([
            { "chunk": "imports", "first": 1, "last": 1 },
            { "chunk": "body", "first": 2, "last": 3 },
        ])
    );
    assert!(entry.get("lines").is_none(), "no line numbers are recorded");
    assert!(entry.get("sources").is_none(), "nor source files");
}

#[test]
fn indentation_follows_the_reference_site() {
    let body = "#file(\"main.py\", ```py\nif True:\n    <<body>>\n```)\n\n#chunk(\"body\", ```py\nprint(1)\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main.py"),
        "if True:\n    print(1)\n"
    );
}

#[test]
fn a_chunk_written_indented_in_the_document_is_still_dedented() {
    let body = "#file(\"main.py\", ```py\nif x:\n    <<body>>\n```)\n\n- step one:\n\n  #chunk(\"body\", ```py\n  print(1)\n  print(2)\n  ```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main"),
        "if x:\n    print(1)\n    print(2)\n"
    );
}

#[test]
fn a_chapter_can_hold_the_fragment_another_file_references() {
    // Documents are chapters of one program: prose in one, the fragment in another,
    // the file that pulls them together in a third.
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    write_doc(
        dir.path(),
        "chapter.typ",
        "= Chapter one\n\n#chunk(\"greeting\", ```py\nprint('hi')\n```)\n",
    );
    write_doc(
        dir.path(),
        "book.typ",
        "= The program\n\n#file(\"src/main.py\", ```py\n<<greeting>>\n```)\n",
    );
    let path = dir.path().to_path_buf();

    let output = lp(
        &path,
        &["tangle", "book.typ", "chapter.typ", "--out", "out"],
    );
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("main"),
        "print('hi')\n"
    );

    let mapped = lp(
        &path,
        &[
            "map",
            "--file",
            "src/main.py",
            "--line",
            "1",
            "--out",
            "out",
        ],
    );
    assert!(
        stdout(&mapped).starts_with("chunk ⟪greeting⟫, line 1 of it"),
        "{}",
        stdout(&mapped)
    );

    // A run with no file declarations anywhere is still an error.
    let no_files = lp(&path, &["tangle", "chapter.typ", "--out", "out2"]);
    assert!(!no_files.status.success());
    assert!(
        stderr(&no_files).contains("no file declarations"),
        "{}",
        stderr(&no_files)
    );
}

#[test]
fn maps_live_next_to_the_files_they_explain() {
    let body =
        "#file(\"a.py\", ```py\nprint('a')\n```)\n\n#file(\"src/b.py\", ```py\nprint('b')\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let root: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(dir.join("out/.lpmap.json")).expect("root map"),
    )
    .expect("json");
    let nested: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(dir.join("out/src/.lpmap.json")).expect("nested map"),
    )
    .expect("json");
    assert!(root["files"].get("a.py").is_some(), "{root}");
    assert!(
        root["files"].get("src/b.py").is_none(),
        "the root map must not index the subtree: {root}"
    );
    assert!(nested["files"].get("b.py").is_some(), "{nested}");

    for file in ["src/b.py", "b.py"] {
        let output = lp(
            &dir,
            &["map", "--file", file, "--line", "1", "--out", "out"],
        );
        assert!(output.status.success(), "{file}: {}", stderr(&output));
        assert!(
            stdout(&output).starts_with("chunk ⟪src/b.py⟫"),
            "{file}: {}",
            stdout(&output)
        );
    }
}

#[test]
fn an_ambiguous_file_name_is_an_error_not_a_guess() {
    let body = "#file(\"one/b.py\", ```py\nprint('a')\n```)\n\n#file(\"two/b.py\", ```py\nprint('b')\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let output = lp(
        &dir,
        &["map", "--file", "b.py", "--line", "1", "--out", "out"],
    );
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("which map?"),
        "{}",
        stderr(&output)
    );

    let explicit = lp(
        &dir,
        &["map", "--file", "two/b.py", "--line", "1", "--out", "out"],
    );
    assert!(explicit.status.success(), "{}", stderr(&explicit));
}

#[test]
fn check_names_the_chunk_of_the_first_difference() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out", "--check"])
            .status
            .success()
    );

    std::fs::write(dir.join("out/main.py"), "hand edited\n").expect("write");
    let drift = lp(&dir, &["tangle", "demo.typ", "--out", "out", "--check"]);
    assert!(!drift.status.success(), "drift must fail");
    let message = stderr(&drift);
    assert!(
        message.contains("STALE  main.py (line 1, in chunk ⟪imports⟫)"),
        "{message}"
    );

    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out", "--check"])
            .status
            .success()
    );
}

#[test]
fn the_map_follows_the_document_even_when_no_output_byte_changes() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    // Prose above the declarations shifts nothing in the output; the map must
    // still be rewritten so it keeps describing the document.
    let moved = format!(
        "{}\n{}",
        "#import \"lp.typ\": chunk, file, rule\n#show: rule", DOC
    );
    std::fs::write(dir.join("demo.typ"), &moved).expect("rewrite");

    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        !stdout(&output).contains("wrote"),
        "outputs are unchanged: {}",
        stdout(&output)
    );

    let forward = lp(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(
        stdout(&forward).starts_with("chunk ⟪body⟫, line 2 of it"),
        "{}",
        stdout(&forward)
    );
}

#[test]
fn dangling_reference_quotes_the_line() {
    let body = "#file(\"main.py\", ```py\n<<missing>>\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(
        message.contains("chunk ⟪missing⟫ is not defined"),
        "{message}"
    );
    assert!(
        message.contains("<<missing>>"),
        "the line is quoted: {message}"
    );
    assert!(
        message.contains("in chunk ⟪main.py⟫, line 1 of it"),
        "{message}"
    );
}

#[test]
fn cycle_is_reported() {
    let body = "#file(\"main.py\", ```py\n<<a>>\n```)\n\n#chunk(\"a\", ```py\n<<b>>\n```)\n\n#chunk(\"b\", ```py\n<<a>>\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("cycle in chunks"),
        "{}",
        stderr(&output)
    );
}

#[test]
fn an_empty_chunk_is_an_error() {
    let body = "#file(\"main.py\", ```py\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(stderr(&output).contains("is empty"), "{}", stderr(&output));
}

#[test]
fn a_file_declaration_can_name_a_nested_path() {
    let body = "#file(\"src/main.rs\", ```rust\nfn main() {}\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(dir.join("out/src/main.rs")).expect("nested"),
        "fn main() {}\n"
    );
}

#[test]
fn unsafe_paths_are_rejected() {
    let body = "#file(\"../escape.txt\", ```text\nx\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("unsafe chunk name"),
        "{}",
        stderr(&output)
    );
}

#[test]
fn map_names_the_chunk_a_generated_line_came_from() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let output = lp(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        stdout(&output).lines().next(),
        Some("chunk ⟪body⟫, line 2 of it")
    );

    // Reverse: which generated lines came from that chunk?
    let reverse = lp(&dir, &["map", "--typ", "body", "--out", "out"]);
    assert!(reverse.status.success(), "{}", stderr(&reverse));
    assert!(
        stdout(&reverse).contains("main.py:2"),
        "{}",
        stdout(&reverse)
    );
    assert!(
        stdout(&reverse).contains("main.py:3"),
        "{}",
        stdout(&reverse)
    );
}

#[test]
fn explain_rewrites_diagnostics_to_the_chunk() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let mut child = Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(["explain", "--out", "out"])
        .current_dir(&dir)
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .expect("spawn");

    use std::io::Write;
    child
        .stdin
        .as_mut()
        .expect("stdin")
        .write_all(b"out/main.py:3:1: boom\n")
        .expect("write");
    let output = child.wait_with_output().expect("wait");

    assert!(stdout(&output).contains("out/main.py:3:1: boom"));
    let message = stderr(&output);
    assert!(message.contains("chunk ⟪body⟫, line 2 of it"), "{message}");
}

#[test]
fn list_reports_declarations() {
    let (_guard, dir, _) = project(DOC);
    let output = lp(&dir, &["list", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let listed = stdout(&output);
    assert!(listed.contains("file  ⟪main.py⟫"), "{listed}");
    assert!(listed.contains("frag  ⟪body⟫"), "{listed}");
    assert!(listed.contains("outputs: <main.py>"), "{listed}");
    assert!(
        !listed.contains("not a chunk"),
        "an undeclared block is not a chunk: {listed}"
    );
}

#[test]
fn a_chunk_built_by_code_is_attributed_to_itself() {
    // The declaration is written once, inside a loop. There is no line to point at
    // and none is invented; the chunk it produced is named instead.
    let body = "#for i in range(2) [\n  #file(\"gen-\" + str(i) + \".py\", ```py\n  print(#i)\n  ```)\n]\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(dir.join("out/gen-0.py").exists());
    assert!(dir.join("out/gen-1.py").exists());

    let mapped = lp(
        &dir,
        &["map", "--file", "gen-0.py", "--line", "1", "--out", "out"],
    );
    assert!(
        stdout(&mapped).starts_with("chunk ⟪gen-0.py⟫, line 1 of it"),
        "{}",
        stdout(&mapped)
    );
}

#[test]
fn the_declaration_is_where_the_line_lives() {
    // A sanity check that the document text itself is what the chunk quotes back,
    // which is what makes "find it with rg" work.
    let (_guard, _dir, text) = project(DOC);
    assert!(line_of(&text, "#chunk(\"imports\"") > 0);
    assert!(line_of(&text, "print('two')") > 0);
}
````)

#file("tests/lazy.rs", ````rust
//! The lazy contract: a pass touches only what actually changed, refuses to
//! tangle a document that does not evaluate, and keeps the line map usable in
//! both directions.

use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../lit/lp.typ");

/// The two references are spliced in: a line that is exactly `<<name>>` would be
/// expanded when this file is tangled (ADR D15).
const DOC: &str = concat!(
    "\
= Demo

#file(\"main.py\", ```py
",
    "<<imports>>\n",
    "<<body>>\n",
    "\
```)

#chunk(\"imports\", ```py
import sys
```)

#chunk(\"body\", ```py
print('one')
```)

#chunk(\"body\", ```py
print('two')
```)
",
);

fn lp(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(args)
        .current_dir(dir)
        .output()
        .expect("run lp")
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).to_string()
}

fn write_doc(dir: &Path, name: &str, body: &str) {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    let text = format!("#import \"lp.typ\": chunk, file, rule\n#show: rule\n{body}");
    std::fs::write(dir.join(name), text).expect("doc");
}

fn project() -> (TempDir, std::path::PathBuf) {
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "demo.typ", DOC);
    write_doc(
        dir.path(),
        "second.typ",
        "#file(\"other.py\", ```py\nprint('second')\n```)\n",
    );
    let path = dir.path().to_path_buf();
    (dir, path)
}

fn modified(path: &Path) -> std::time::SystemTime {
    std::fs::metadata(path)
        .expect("metadata")
        .modified()
        .expect("mtime")
}

#[test]
fn a_pass_does_not_touch_files_that_did_not_change() {
    let (_guard, dir) = project();
    let first = lp(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"]);
    assert!(first.status.success(), "{}", stderr(&first));
    assert!(stdout(&first).contains("wrote  main.py"));
    assert!(stdout(&first).contains("wrote  other.py"));

    let before = (
        modified(&dir.join("out/main.py")),
        modified(&dir.join("out/other.py")),
        modified(&dir.join("out/.lpmap.json")),
    );
    std::thread::sleep(std::time::Duration::from_millis(30));

    let second = lp(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"]);
    assert!(second.status.success(), "{}", stderr(&second));
    assert!(
        !stdout(&second).contains("wrote"),
        "nothing should be rewritten: {}",
        stdout(&second)
    );

    let after = (
        modified(&dir.join("out/main.py")),
        modified(&dir.join("out/other.py")),
        modified(&dir.join("out/.lpmap.json")),
    );
    assert_eq!(before, after, "a no-op pass must not touch mtimes");
}

#[test]
fn only_the_affected_output_is_rewritten() {
    let (_guard, dir) = project();
    assert!(
        lp(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"])
            .status
            .success()
    );

    write_doc(
        dir.as_path(),
        "demo.typ",
        &DOC.replace("print('two')", "print('three')"),
    );

    let output = lp(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let report = stdout(&output);
    assert!(report.contains("wrote  main.py"), "{report}");
    assert!(
        !report.contains("wrote  other.py"),
        "the untouched document must not be rewritten: {report}"
    );
    assert!(
        std::fs::read_to_string(dir.join("out/main.py"))
            .expect("main")
            .contains("print('three')")
    );
}

#[test]
fn a_half_written_document_is_not_tangled() {
    let (_guard, dir) = project();
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    let good = std::fs::read_to_string(dir.join("out/main.py")).expect("main");

    // Mid-edit, the document does not evaluate: nothing is tangled and the last
    // good output stays where it is.
    write_doc(
        dir.as_path(),
        "demo.typ",
        &DOC.replace("#file(\"main.py\", ```py", "#file(\"main.py\", `"),
    );

    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(
        !output.status.success(),
        "a document that does not evaluate must not be tangled"
    );
    let message = stderr(&output);
    assert!(message.contains("did not evaluate"), "{message}");
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main"),
        good
    );
}

#[test]
fn map_works_in_both_directions() {
    let (_guard, dir) = project();
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    // Forward: which chunk produced this generated line?
    let forward = lp(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(forward.status.success(), "{}", stderr(&forward));
    assert!(
        stdout(&forward).starts_with("chunk ⟪body⟫, line 2 of it"),
        "{}",
        stdout(&forward)
    );

    // Reverse: which generated lines came from that chunk?
    let reverse = lp(&dir, &["map", "--typ", "body", "--out", "out"]);
    assert!(reverse.status.success(), "{}", stderr(&reverse));
    assert!(
        stdout(&reverse).contains("main.py:3"),
        "{}",
        stdout(&reverse)
    );
}

#[test]
fn unused_fragment_warns_without_failing() {
    let (_guard, dir) = project();
    write_doc(
        dir.as_path(),
        "demo.typ",
        &format!("{DOC}\n#chunk(\"never-used\", ```py\nprint('dead')\n```)\n"),
    );

    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stderr(&output).contains("chunk ⟪never-used⟫ is never referenced"),
        "{}",
        stderr(&output)
    );
}
````)

#file("tests/metadata.rs", ````rust
//! The declaration side: what the document says its chunks are.
//!
//! These tests need the `typst` binary (the tool asks the document, it does not
//! read it), so they skip cleanly when it is not on PATH.

use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../lit/lp.typ");

fn typst_available() -> bool {
    Command::new("typst")
        .arg("--version")
        .output()
        .is_ok_and(|output| output.status.success())
}

fn lp(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(args)
        .current_dir(dir)
        .output()
        .expect("run lp")
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).to_string()
}

/// Write the package and a document that imports it.
fn write(dir: &Path, name: &str, body: &str) {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.join(name),
        format!("#import \"lp.typ\": chunk, file, rule\n#show: rule\n{body}"),
    )
    .expect("doc");
}

#[test]
fn a_styling_show_rule_does_not_hide_a_chunk() {
    // The declaration is what the tool reads, and it is emitted before the block
    // is rendered — so even a show rule that throws the element away cannot hide
    // a chunk. (An instrumented show rule could not survive this; a declaration
    // does not care.)
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    write(
        dir.path(),
        "styled.typ",
        "#show raw.where(block: true): it => [styled away]\n\n#chunk(\"styled\", ```py\nprint('styled')\n```)\n",
    );
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "styled.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let report = stdout(&output);
    assert!(report.contains("styled"), "{report}");
    assert!(report.contains("print('styled')"), "{report}");
}

#[test]
fn a_chapter_is_tangled_without_being_listed() {
    // Typst merges #include'd content, so the tool does not need to be told about
    // every file — the document already says.
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    write(dir.path(), "book.typ", "= Book\n#include \"chapter.typ\"\n");
    write(
        dir.path(),
        "chapter.typ",
        "= Chapter\n\n#file(\"src/main.py\", ```py\nprint('from a chapter')\n```)\n",
    );
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "book.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("output"),
        "print('from a chapter')\n"
    );

    // The output line is attributed to the declaration that produced it.
    let mapped = lp(
        &path,
        &[
            "map",
            "--file",
            "src/main.py",
            "--line",
            "1",
            "--out",
            "out",
        ],
    );
    assert!(
        stdout(&mapped).starts_with("chunk ⟪src/main.py⟫, line 1 of it"),
        "{}",
        stdout(&mapped)
    );
}

#[test]
fn the_document_reports_chunks_no_parser_could_find() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    write(
        dir.path(),
        "dynamic.typ",
        "#file(\"src/main.py\", ```py\n<<part-0>>\n```)\n\n#for i in range(2) [\n  #chunk(\"part-\" + str(i), ```py\n  print(#i)\n  ```)\n]\n",
    );
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "dynamic.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let report = stdout(&output);
    assert!(
        report.contains("part-0") && report.contains("part-1"),
        "{report}"
    );

    // The chunks built by the loop are tangled like any other.
    let tangled = lp(&path, &["tangle", "dynamic.typ", "--out", "out"]);
    assert!(tangled.status.success(), "{}", stderr(&tangled));
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("output"),
        "print(#i)\n"
    );
}

#[test]
fn a_document_that_does_not_evaluate_says_so() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("broken.typ"),
        "= Broken\n\n#undefined-thing(1)\n",
    )
    .expect("doc");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "broken.typ"]);
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(message.contains("did not evaluate"), "{message}");
    assert!(
        message.contains("undefined-thing"),
        "typst's own diagnostic: {message}"
    );
}

#[test]
fn a_document_outside_the_working_directory_can_be_tangled() {
    // The wrapper document has to live where Typst's root can reach the file it
    // includes, so it goes next to the documents rather than in the cwd.
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let documents = TempDir::new().expect("documents");
    write(
        documents.path(),
        "book.typ",
        "#file(\"src/main.py\", ```py\nprint('elsewhere')\n```)\n",
    );

    let workdir = TempDir::new().expect("workdir");
    let doc = documents.path().join("book.typ");
    let out = workdir.path().join("out");
    let output = lp(
        workdir.path(),
        &[
            "tangle",
            doc.to_str().expect("utf8"),
            "--out",
            out.to_str().expect("utf8"),
        ],
    );
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(out.join("src/main.py")).expect("output"),
        "print('elsewhere')\n"
    );

    // And the wrapper is gone again.
    let leftovers: Vec<String> = std::fs::read_dir(documents.path())
        .expect("read_dir")
        .flatten()
        .map(|entry| entry.file_name().to_string_lossy().to_string())
        .filter(|name| name.starts_with(".lp-decl-"))
        .collect();
    assert!(
        leftovers.is_empty(),
        "wrapper files left behind: {leftovers:?}"
    );
}

#[test]
fn a_declaration_of_an_unknown_kind_is_an_error() {
    // Only `chunk` and `file` exist; anything else means the package and the tool
    // disagree, and that must not be read as a fragment.
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("odd.typ"),
        "= Odd\n\n#metadata((lp: \"sideways\", name: \"x\", text: \"y\"))<lp-decl>\n",
    )
    .expect("doc");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "odd.typ"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("unknown declaration kind"),
        "{}",
        stderr(&output)
    );
}

#[test]
fn a_document_without_declarations_says_what_to_do() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("plain.typ"),
        "= Just prose\n\n```py\nprint('not a chunk')\n```\n",
    )
    .expect("doc");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "plain.typ"]);
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(message.contains("declares no chunks"), "{message}");
    assert!(
        message.contains("#file("),
        "the remedy belongs there: {message}"
    );
}
````)

#file("tests/owned.rs", ````rust
//! Nothing under the output directory may go unaccounted for.
//!
//! A file is either produced by a declaration, declared in a `.lpignore`, or an
//! error the user resolves — by declaring it, or by deleting it on purpose. `lp`
//! never removes anything on its own, and it never lets a stray file pass
//! silently.

use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../lit/lp.typ");

const DOC: &str = "\
= Demo

#file(\"a.py\", ```py
print('a')
```)

#file(\"src/b.py\", ```py
print('b')
```)
";

const IGNORES: &str = "\
# files lp must not touch
handwritten.txt
build/
*.lock
";

fn lp(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(args)
        .current_dir(dir)
        .output()
        .expect("run lp")
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).to_string()
}

/// Write a document in the real authoring form, plus the package it imports.
fn write_doc(dir: &Path, name: &str, body: &str) -> String {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    let text = format!("#import \"lp.typ\": chunk, file, rule\n#show: rule\n{body}");
    std::fs::write(dir.join(name), &text).expect("doc");
    text
}

/// A project tangled into an output directory with the given declaration.
fn tangled(declaration: &str, extra: &[(&str, &str)]) -> (TempDir, std::path::PathBuf) {
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "doc.typ", DOC);
    if !declaration.is_empty() {
        std::fs::create_dir_all(dir.path().join("out")).expect("out");
        std::fs::write(dir.path().join("out/.lpignore"), declaration).expect("ignore file");
    }
    for (relative, contents) in extra {
        let path = dir.path().join("out").join(relative);
        std::fs::create_dir_all(path.parent().expect("parent")).expect("dir");
        std::fs::write(&path, contents).expect("file");
    }
    let path = dir.path().to_path_buf();
    let output = lp(&path, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    (dir, path)
}

/// The same document without the `src/b.py` declaration.
fn without_b() -> String {
    DOC.replace("\n#file(\"src/b.py\", ```py\nprint('b')\n```)\n", "")
}

#[test]
fn a_dropped_declaration_is_an_error_until_it_is_resolved() {
    let (_guard, dir) = tangled(IGNORES, &[("handwritten.txt", "kept")]);
    write_doc(&dir, "doc.typ", &without_b());
    assert!(dir.join("out/src/b.py").exists());

    // The leftover is an error, not something quietly removed.
    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(message.contains("nothing accounts for"), "{message}");
    assert!(message.contains("src/b.py"), "{message}");
    assert!(
        message.contains("lp unaccounted --delete"),
        "the remedy belongs there: {message}"
    );
    assert!(
        dir.join("out/src/b.py").exists(),
        "nothing is removed for you"
    );

    // The report agrees, and says so with its exit code.
    let report = lp(&dir, &["unaccounted", "doc.typ", "--out", "out"]);
    assert_eq!(report.status.code(), Some(1));
    assert!(stdout(&report).contains("src/b.py"), "{}", stdout(&report));

    // One remedy: declare it. Then everything is accounted for again.
    let mut declaration = std::fs::read_to_string(dir.join("out/.lpignore")).expect("ignore");
    declaration.push_str("src/b.py\n");
    std::fs::write(dir.join("out/.lpignore"), &declaration).expect("ignore");
    let declared = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(declared.status.success(), "{}", stderr(&declared));
    assert!(dir.join("out/src/b.py").exists(), "declared, so kept");

    // The other: delete it deliberately.
    std::fs::write(dir.join("out/.lpignore"), IGNORES).expect("ignore");
    let deleted = lp(
        &dir,
        &["unaccounted", "doc.typ", "--out", "out", "--delete"],
    );
    assert!(deleted.status.success(), "{}", stderr(&deleted));
    assert!(
        stdout(&deleted).contains("deleted src/b.py"),
        "{}",
        stdout(&deleted)
    );
    assert!(!dir.join("out/src/b.py").exists());
    assert!(
        !dir.join("out/src").exists(),
        "the emptied directory goes too"
    );

    let clean = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(clean.status.success(), "{}", stderr(&clean));
    assert!(
        !dir.join("out/src/.lpmap.json").exists(),
        "the stale map is gone"
    );
    assert!(
        lp(&dir, &["tangle", "doc.typ", "--out", "out", "--check"])
            .status
            .success()
    );
}

#[test]
fn declared_files_are_accounted_for() {
    let (_guard, dir) = tangled(
        IGNORES,
        &[
            ("handwritten.txt", "kept by hand"),
            ("build/art.txt", "not ours"),
            ("Cargo.lock", "foreign"),
        ],
    );
    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        !stderr(&output).contains("nothing accounts for"),
        "{}",
        stderr(&output)
    );
    for kept in [
        "out/handwritten.txt",
        "out/build/art.txt",
        "out/Cargo.lock",
        "out/.lpignore",
    ] {
        assert!(dir.join(kept).exists(), "{kept} must survive");
    }
}

#[test]
fn the_pattern_language_is_gitignores() {
    let (_guard, dir) = tangled(
        "build/\n**/*.log\n",
        &[
            ("build/art.txt", "not ours"),
            ("deep/nested/app.log", "log"),
        ],
    );
    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(dir.join("out/build/art.txt").exists(), "directory pattern");
    assert!(dir.join("out/deep/nested/app.log").exists(), "** pattern");
}

#[test]
fn a_deeper_ignore_file_can_take_a_file_back() {
    let (_guard, dir) = tangled(
        "src/*\n",
        &[
            ("src/stale.py", "ours after all"),
            ("src/other.py", "protected"),
        ],
    );
    std::fs::write(dir.join("out/src/.lpignore"), "!stale.py\n").expect("ignore");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("src/stale.py"),
        "{}",
        stderr(&output)
    );
    assert!(dir.join("out/src/other.py").exists(), "still protected");
}

#[test]
fn control_files_survive_and_other_dotfiles_are_ordinary_files() {
    let (_guard, dir) = tangled("kept.dot\n", &[("kept.dot", "x")]);
    std::fs::write(dir.join("out/stray.cache"), "not listed").expect("file");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(
        !output.status.success(),
        "an unlisted dotfile is a stray like any other"
    );
    assert!(
        stderr(&output).contains("stray.cache"),
        "{}",
        stderr(&output)
    );
    assert!(
        dir.join("out/.lpmap.json").exists(),
        "the line map is never content"
    );
    assert!(dir.join("out/.lpignore").exists(), "nor are the rules");
    assert!(dir.join("out/kept.dot").exists(), "listed, so kept");
}

#[test]
fn a_git_directory_is_ordinary_content() {
    // Nothing is special-cased, not even a repository: built here rather than by
    // the helper because the first tangle is supposed to fail.
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "doc.typ", DOC);
    std::fs::create_dir_all(dir.path().join("out/.git")).expect("out");
    std::fs::write(dir.path().join("out/.lpignore"), IGNORES).expect("ignore");
    std::fs::write(dir.path().join("out/.git/config"), "[core]\n").expect("file");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success(), "not special-cased");
    assert!(
        stderr(&output).contains(".git/config"),
        "{}",
        stderr(&output)
    );

    // The escape hatch is the declaration, like for anything else.
    let (_guard, declared) = tangled(".git/\n", &[(".git/config", "[core]\n")]);
    assert!(declared.join("out/.git/config").exists());
}

#[test]
fn check_reports_a_stray_without_removing_it() {
    let (_guard, dir) = tangled(IGNORES, &[("handwritten.txt", "kept")]);
    std::fs::write(dir.join("out/leftover.py"), "stale").expect("stray");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out", "--check"]);
    assert!(!output.status.success(), "drift");
    assert!(
        stderr(&output).contains("leftover.py"),
        "{}",
        stderr(&output)
    );
    assert!(
        dir.join("out/leftover.py").exists(),
        "--check changes nothing"
    );
}

#[test]
fn deleting_a_foreign_subtree_takes_one_line_and_one_command() {
    let (_guard, dir) = tangled(IGNORES, &[("handwritten.txt", "kept")]);
    std::fs::create_dir_all(dir.join("out/vendor/nested")).expect("dir");
    std::fs::write(dir.join("out/vendor/a.txt"), "x").expect("file");
    std::fs::write(dir.join("out/vendor/nested/b.txt"), "x").expect("file");

    let report = lp(&dir, &["unaccounted", "doc.typ", "--out", "out"]);
    assert_eq!(report.status.code(), Some(1));
    assert!(
        stdout(&report).contains("vendor/a.txt"),
        "{}",
        stdout(&report)
    );

    let deleted = lp(
        &dir,
        &["unaccounted", "doc.typ", "--out", "out", "--delete"],
    );
    assert!(deleted.status.success(), "{}", stderr(&deleted));
    assert!(!dir.join("out/vendor").exists());
    assert!(dir.join("out/handwritten.txt").exists());
}

#[test]
fn without_a_declaration_a_stray_is_still_an_error() {
    let (_guard, dir) = tangled("", &[]);
    std::fs::write(dir.join("out/stray.txt"), "who put this here").expect("stray");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(stderr(&output).contains("stray.txt"), "{}", stderr(&output));
    assert!(dir.join("out/stray.txt").exists(), "and nothing removes it");
}

#[test]
fn a_missing_output_directory_is_not_an_io_error() {
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "doc.typ", DOC);
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "doc.typ", "--out", "out", "--check"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("STALE  a.py (file missing)"),
        "{}",
        stderr(&output)
    );
    assert!(!path.join("out").exists(), "--check writes nothing at all");
}
````)

#file("tests/self.rs", ````rust
//! Self-reproduction: the document has to regenerate the crate it ships.

use std::path::Path;
use std::process::Command;

/// The document is the source of the files that are compiled, so `--check` in the
/// crate root has to be clean. This is the permanent half of the fixed point:
/// Stage 1 also required the output to equal the frozen seed in `seed/`,
/// which stopped being true the moment the document was refactored (ADR D15).
#[test]
fn the_document_regenerates_the_sources_we_are_running() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR"));
    let output = Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(["tangle", "lp.typ", "--out", ".", "--check"])
        .current_dir(root)
        .output()
        .expect("run lp");

    assert!(
        output.status.success(),
        "--check reported drift between lp.typ and the sources it generated:\n{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
}
````)

#file(".agents/skills/literate-programming/SKILL.md", `````markdown
---
name: literate-programming
description: Write a program as an exposition - one Typst document whose subject is the thinking (the problem, the alternatives, the choice and why), with the code quoted in as the evidence that makes it checkable and tangled out of it into real source files and a woven PDF. Use when writing or editing any program lp carries (including this repository's own lp.typ), adding or reorganising chunks, or asked to write a literate document. Reading front to back has to go from idea to detail; the tool checks only the mechanism, so the thinking is the writer's job.
---

# Literate programming

Literate means the document is **about the thinking**. A literate program is an exposition — what the problem is, what was tried, what was chosen and why — and the code is the evidence that makes those decisions run. The code is quoted *into* the argument; it is never the subject of it.

One source, two products: **tangle** (the machine's copy: real source files) and **weave** (the reader's copy: a typeset document). Neither is the original; the exposition is.

So the question is never "what code goes here" but "what am I saying here, and what does it need to show". Read front to back, the document has to be **progressive disclosure**: each section states its thought, and the ones that follow take it further. A reader who has to jump around, or who meets a detail before the idea that made it necessary, is reading a document that was not finished.

## The discipline: the thinking is the subject

`lp` can check the mechanism (table below). It cannot read. The part that matters is on you:

1. **Every section is a claim.** Be able to say it in one sentence before you write the section. If you cannot, it is not a thought yet — it is a place to put code.
2. **The code is evidence, never the subject.** It appears so the reader can check the claim, not so the file can exist. A chunk written because "the file needs it" means the idea that needs it has not been written down.
3. **Write the why: the constraint, the alternative, and the moment of choice.** A reader can reconstruct what the code does; they cannot reconstruct what you rejected, or why the obvious design was wrong. That part exists only if you write it.
4. **Prose the thinking; captions are not prose.** "An operator consumes the two numbers produced before it" is a thought. "We call `pop` twice" is a caption for code, and captions belong in code.
5. **Name ideas, not implementations.** `<<apply one token>>` is a step in an argument; `<<pop two operands>>` is an implementation detail. When a name could be a function name, the idea above it is missing.
6. **One idea per paragraph, one promise per chunk.** A body keeps exactly the promise its name made: not more, not less, and not something the prose described differently. One name per concept, in the prose and in the chunks alike.
7. **Say what is not true yet.** Limits, planned work, trade-offs taken, the case the code does not handle: put them where the reader meets them.
8. **Revise the thinking first, and read for it before saying done.** When the design changes the opening is what goes stale; and the last pass is reading the exposition front to back — can someone rebuild the design from the reasoning? — not reviewing the diff. Then run the checks.

The failure mode to avoid is prose that *sounds* explained. A confident paragraph that does not match its chunk is worse than no paragraph: it stops the next reader — human or agent — from looking at the code.

## What the tool enforces (it will refuse these)

| Invariant | Message |
| --- | --- |
| Every reference resolves; no cycles; no empty bodies | `chunk ⟪x⟫ is not defined` / `cycle in chunks:` / `chunk ⟪x⟫ is empty` |
| Every file under `--out` is produced by a chunk or declared | `nothing accounts for these files` |
| The generated files still equal the document | `--check` prints `STALE` |

That is the whole list, and it is deliberately about *mechanism*: the tool can tell that a reference points at something and that the output still matches the text. It cannot tell whether a section states a thought, whether the order suits a reader, or whether the prose is true — mechanism is all it knows (see below).

## The shape: a file is the list of thoughts the reader already has

When the ideas come first, the file's shape falls out of them. A root chunk (`#file`) is a skeleton — a few lines that name the parts; fragments (`#chunk`) are those parts, each explained in the section that belongs to it. Depth is whatever the explanation needs: a step can itself be a skeleton of steps.

The line between a skeleton and a dump is the line between ideas: if you cannot say what a fragment is *for* in the argument, it is too small, or not yet thought through.

````
#file("src/calc.py", ```python
"""An RPN calculator: `calc.py "2 3 + 4 *"` prints 20.0."""

@<<imports>>

@<<the operation table>>


def evaluate(tokens):
    @<<the evaluation loop>>
@<<the command line>>
```)
````

Everything above is a promise. Later sections keep them, one at a time:

````
#chunk("the evaluation loop", ```python
stack = []
for token in tokens:
    @<<apply one token>>
return stack.pop()
```)
````

Two things this buys: a reader can stop at any level and still have a true account of the program, and every name in the text has exactly one place where it is filled in.

**The order of the declarations is free, and it is an editorial decision.** Two shapes both work, and the argument decides which one the reader wants:

- *Skeleton first* (what the example does): show the files, then fill them in section by section. The reader knows the shape from the first page.
- *Pieces first, assembly last*: explain the important idea and build its fragments as the text goes, then assemble them into files in a short final section. The reader meets each idea where it is worth explaining, and sees the whole only when they can appreciate it.

Neither is more literate than the other. What is *not* a matter of taste is that the prose must say which one it is doing: if files appear at the end, the opening has to promise that.

## Mechanics

- `#file(path, code)` — a root chunk. Its name is the path it tangles to; every produced file needs one, and nothing else produces files.
- `#chunk(name, code)` — a fragment, existing only where something refers to it.
- `<<name>>` **alone on its line** is a reference; anywhere else (`a << b`) it stays literal text.
- **Indentation comes from the reference line**, not the chunk's own text: write chunk bodies flush left and let the reference place them. Nested references compose, so a body pulled in at four spaces and pulled in again at four more lands at eight.
- A repeated name **concatenates in document order** — a file can be introduced where its interface belongs and finished where its behaviour belongs. Nothing is inherited between the pieces: blank lines at the top of a later piece are part of what it contributes.
- The fence's language tag is data (the tangled file's language, and the input to the language check). Nothing in `lp` parses it.
- **To quote the syntax itself, escape it**: a line `@<<name>>` tangles out as `<<name>>` — the `@` is dropped and the line is never expanded, never counted as a reference. That is how a document can show what a reference looks like (this file is carried by `lp.typ` and does exactly that).
- Block content is verbatim: keep it flush left, and **use four backticks as the fence** whenever the code contains three (Typst fixtures, Markdown fences, heredocs).
- Keep the document evaluable at every save; a document Typst cannot evaluate tangles nothing, and `lp watch` keeps the last good output instead of half of a new one.

## Working loop

1. **Outline the argument first**: sections in reading order, each one a step from idea to detail.
2. **Write the skeleton** (the root chunks), naming parts the reader will meet later.
3. **Keep the promises** in the sections that follow — prose, then the chunk.
4. `lp tangle <doc.typ> --out <dir> --check` — dry run, exit 1 on drift.
5. `lp watch <doc.typ> --out <dir> --check-cmd '<build>'` — only changed bytes are rewritten, and diagnostics come back as chunk names.
6. `lp explain` (pipe `cargo build --message-format=short` into it) or `lp map --file <generated> --line N` to find the chunk a diagnostic came from. `--out` has to be repeated on `map`, `explain` and `unaccounted`; they default to `out`.
7. **Resolve strays** after deleting or renaming a root: `lp unaccounted <doc> --out <dir>`. Declare what is not the document's in that directory's `.lpignore` (matching means *protect*, and it includes anything the program writes next to its own output, like a byte-compiler cache); `lp unaccounted … --delete` is the explicit alternative. `lp` never deletes by itself.

## Find your way around

| Question | Command |
| --- | --- |
| Which chunks exist, in what order, which are roots | `lp list <doc.typ>` |
| The declaration stream as Typst evaluated it (also the reading order) | `lp metadata <doc.typ>` |
| Where line N of `src/main.rs` came from | `lp map --file src/main.rs --line N` |
| What generated lines a chunk produced | `lp map --typ X` |
| The declaration itself | `rg '#chunk\("X"'` |

Provenance is chunk-level on purpose — which declaration, and which line inside it — never a `.typ` line number (Typst does not expose source positions). To edit, go to the declaration the diagnostic names.

## Errors you will hit

| Message | Cause | Fix |
| --- | --- | --- |
| `chunk ⟪x⟫ is not defined` | a reference to nothing | declare it, or fix the typo |
| `cycle in chunks:` | fragments referencing each other | break the cycle; an article is a DAG |
| `chunk ⟪x⟫ is empty` | a declaration with no body | delete it or fill it |
| `nothing accounts for these files` | files under `--out` that no chunk produces and no `.lpignore` declares | declare them, or `--delete` |
| "the document did not evaluate" | a Typst error — unclosed fence, bad expression | fix the document; nothing was tangled |
| a literal `<<name>>` line came out as something else | that line was read as a reference | write `@<<name>>` where the text itself is wanted |

## Anti-patterns

- Prose that restates the code ("this function adds two numbers"). It looks literate and is not.
- Details before names — the tool rejects it, and it is the same mistake the rule is there to prevent.
- A chunk per statement; five-line chunks with no narrative; a document that is a tangle script with headings.
- Hand-editing tangled files, or creating an output file by hand instead of declaring it.
- A first section that describes the design you had an hour ago.

## In this repository (`lp` is self-hosted)

`lp.typ` is the source of the tool: it declares `Cargo.toml`, `src/*.rs`, `tests/*.rs` and this skill, all of which are generated (gitignored). Change the tool by changing `lp.typ`:

```sh
nix develop -c ./target/debug/lp tangle lp.typ --out . --check   # the gate
nix develop -c ./target/debug/lp watch lp.typ --out . --check-cmd 'cargo build --message-format=short'
nix develop -c cargo test                                          # 49 tests, includes self-reproduction
```

A fresh clone has no `src/`: build the frozen seed in `seed/`, then tangle (see `README.md` §自举). `tests/self.rs` fails if the files on disk stop matching the document, so hand-editing `src/` cannot survive. Adding a top-level directory means adding one line to the root `.lpignore`.

## References

- [`references/example.md`](references/example.md) — a complete two-file program in the skeleton shape, with a real transcript.
- [`references/thinking.md`](references/thinking.md) — where this stance comes from (Knuth's argument, noweb's simplifications), and the strongest objections to it, honestly stated.
- Repository: `README.md` (full contract), `AGENTS.md` (project rules), `examples/demo/` (runnable example), `agent-notes/decisions/2026-09-11-document-invariants.md` (the enforced invariants).
`````)

#file(".agents/skills/literate-programming/references/example.md", `````markdown
# Worked example: an RPN calculator

Two files, no framework, and an exposition you can check. The first paragraph is the design
decision — why reverse Polish notation makes the grammar disappear — and everything after it
exists to make that decision inspectable: the code is what the decision looks like when it has
to run. The roots are skeletons that name their parts, and each part is explained in its own
section (skeleton-first is one of the two legitimate shapes; pieces-first, assembly-last would do
just as well). The document below is the actual source; it was tangled and run on 2026-09-11 with
`lp` 0.1.0 and typst 0.15.1. The transcript at the end is real output.

## What the document decides

| Decision | Where to look |
| --- | --- |
| Idea before shape before detail | the RPN paragraph explains why there is no precedence parser; then the whole file appears |
| Every root is a skeleton | `src/calc.py` names `<<imports>>`, `<<the operation table>>`, `<<the evaluation loop>>`, `<<the command line>>` |
| Depth is two levels here | the skeleton names `<<the evaluation loop>>`, which names `<<apply one token>>` |
| Each name is explained where it is used | the loop is explained as stack policy; the one token step is explained with the indentation rule |
| Prose keeps the promise | the table-versus-`if`-chain paragraph is the reason the table exists; nothing else claims to be |
| A file can be declared twice | not used here — `examples/demo/literate.typ` in the repository shows it |

## The document (`calc.typ`)

````
#import "lit/lp.typ": chunk, file, rule
#show: rule

= An RPN calculator

This document is an argument, read from the front. It starts with the shape of the
program and gets more specific as it goes: the first section is the whole file with
nothing filled in, and every name in it is explained by a later section. A reader who
stops after the first section still knows what the program is.

The program is a reverse Polish calculator. That choice is worth one paragraph, because
it is where all the difficulty went: in `2 + 3 * 4` the order of operations lives in a
grammar — precedence, parentheses, associativity. In `2 3 + 4 *` it lives in the input,
and the evaluator is left with a stack and no grammar at all.

== The shape of the program

The file, before any of it is explained:

#file("src/calc.py", ```python
"""An RPN calculator: `calc.py "2 3 + 4 *"` prints 20.0."""

@<<imports>>

@<<the operation table>>


def evaluate(tokens):
    @<<the evaluation loop>>
@<<the command line>>
```)

`evaluate` is the interface: tokens in the order they were written, a number out. It
keeps its state in a local stack, so two calls cannot interfere with each other — which
is what makes it testable without touching the outside world.

== What the program needs from outside

Two things. `exit`, because a command line has to be able to say no with a status code.
And `tokenize`, which is the other file in this program, defined in the next section —
`calc.py` never parses text, and `lexer.py` never knows what the tokens mean.

#chunk("imports", ```python
import sys

from lexer import tokenize
```)

== Reading the input

The evaluator wants a stream of tokens; the user has one string. `tokenize` is a
generator, so the string is never split into a list that nobody needs, and the evaluator
can pull one token at a time without knowing where it came from.

The pattern is deliberately permissive — it recognises numbers and the four operator
characters and nothing else. Deciding what a valid *expression* is belongs to the
evaluator, not here; a lexer that tried to do it too would have to know about the stack.

#file("src/lexer.py", ```python
"""Turning an expression into numbers and operators."""

import re

@<<what a token looks like>>


def tokenize(text):
    for match in TOKEN.finditer(text):
        yield match.group(0)
```)

#chunk("what a token looks like", ```python
TOKEN = re.compile(r"\d+\.?\d*|[-+*/]")
```)

== The arithmetic, in one place

Four operations, one table. A chain of `if`s would work and put the arithmetic in the
middle of the evaluation logic; the table keeps the whole of it visible on one screen,
and adding an operator is a line here plus a character in the pattern above — two places
that a reader can check against each other.

#chunk("the operation table", ```python
OPERATIONS = {
    "+": lambda left, right: left + right,
    "-": lambda left, right: left - right,
    "*": lambda left, right: left * right,
    "/": lambda left, right: left / right,
}
```)

== Running the loop

Evaluation is a stack machine: numbers accumulate, operators consume. The loop below is
the whole of that policy — it names one step, and the next section explains what the step
does. Nothing about the step is needed to read this.

The body of the loop arrives in the next section; because the reference below is indented
by four spaces, and it is itself pulled into an indented place, the expansion ends up
eight spaces in. Indentation is relative to the reference that pulled the text in, at
every level.

#chunk("the evaluation loop", ```python
stack = []
for token in tokens:
    @<<apply one token>>
return stack.pop()
```)

== Applying one token

An operator consumes the two numbers produced before it; a number is pushed. Note where
this code ends up: the reference that pulls it in is indented by four spaces, so the loop
body is indented, even though the chunk below is written flush left. The chunk's own
layout is the layout of the text you are reading; the indentation comes from the place
that names it.

`float` is where a bad expression finally fails, and the traceback will point at this
chunk.

#chunk("apply one token", ```python
if token in OPERATIONS:
    right = stack.pop()
    left = stack.pop()
    stack.append(OPERATIONS[token](left, right))
else:
    stack.append(float(token))
```)

== The command line

The tail of `calc.py`, written as one chunk about running the program rather than about
evaluating expressions. It starts with two blank lines on purpose: in the finished file
they are the ones that separate `main` from `evaluate`, and nothing is inherited from the
first declaration of the file.

The exit status is the part scripts depend on: an empty expression gets a usage message
and a non-zero status, everything else prints the result.

#chunk("the command line", ```python


def main(argv):
    expression = " ".join(argv[1:])
    if not expression.strip():
        print("usage: calc.py <expression>")
        return 2
    print(evaluate(tokenize(expression)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```)

== Checking it

Two files, and the only way to know the argument is true is to run it:

```sh
$ lp tangle calc.typ --out . && python3 src/calc.py "2 3 + 4 *"
20.0
```

In a real project the tests would be roots too, one `#file` per test module, each sitting
next to the behaviour it pins down. `examples/demo/literate.typ` in this repository does
that, and also shows a fragment shared by two different files (`<<crate-preamble>>`).
````

## Transcript

```sh
$ lp tangle calc.typ --out .
wrote  src/calc.py  (37 lines, python)
wrote  src/lexer.py  (10 lines, python)

$ python3 src/calc.py '2 3 + 4 *'
20.0

$ lp list calc.typ
calc.typ
  file  ⟪src/calc.py⟫                python
  frag  ⟪imports⟫                    python
  file  ⟪src/lexer.py⟫               python
  frag  ⟪what a token looks like⟫    python
  frag  ⟪the operation table⟫        python
  frag  ⟪the evaluation loop⟫        python
  frag  ⟪apply one token⟫            python
  frag  ⟪the command line⟫           python

outputs: <src/calc.py>, <src/lexer.py>

$ lp map --out . --file src/calc.py --line 19
chunk ⟪apply one token⟫, line 2 of it
    find it with: rg '#chunk("apply one token")'
```

`lp list` is the document's reading order, and it is also the order the tool checks: every
`frag` above appears after the place that first refers to it.

The generated file shows what the indentation rule did. `<<apply one token>>` is written flush
left in the document and pulled in by a reference that is itself four spaces in:

```python
# src/calc.py, tangled
def evaluate(tokens):
    stack = []
    for token in tokens:
        if token in OPERATIONS:      # ← from <<apply one token>>, written flush left
            right = stack.pop()
            left = stack.pop()
            stack.append(OPERATIONS[token](left, right))
```

## Three things the transcript teaches

1. **Anything written next to the generated code becomes unaccounted.** Running the program
   created `src/__pycache__/…`, and the next `--check` refused:

   ```sh
   $ lp tangle calc.typ --out . --check
     × nothing accounts for these files:
     │   src/__pycache__/lexer.cpython-314.pyc
     help: declare each one in the .lpignore of its directory, or delete it with `lp unaccounted --delete`

   $ printf '/calc.typ\n/lit\n/src/__pycache__\n' > .lpignore   # matching means *protect*
   $ lp tangle calc.typ --out . --check
   ok     src/calc.py
   ok     src/lexer.py
   ```

   While ownership was failing, the drift report printed nothing: an empty stdout from `--check`
   means an ownership error, so read stderr. `examples/demo/build/.lpignore` in the repository is
   the same pattern at a larger scale (`target/`, `Cargo.lock`, woven PDFs).
2. **`--out` has to be repeated.** `lp map`, `lp explain` and `lp unaccounted` default to
   `--out out`; a document tangled with `--out .` fails there with `no map knows this file`.
3. **Diagnostic back-translation covers compilers that print `file:line:col:`** — `rustc
   --message-format=short`, gcc, clang — through `lp explain`. Python tracebacks say
   `File "…", line N` and are not parsed yet; for those, `lp map --file … --line N` is the
   language-agnostic path. Adding a Python extractor is a row in a data table, not new algorithm
   (see `src/explain.rs`).
`````)

#file(".agents/skills/literate-programming/references/thinking.md", ````markdown
# Where this stance comes from, and the case against it

Companion to [`../SKILL.md`](../SKILL.md). The long version, with the full map of positions and
sources, is `agent-notes/research/2026-09-11-literate-programming-thinking.md` in the `lp`
repository.

## The stance

- **The subject is the thinking, not the code.** A literate document is an exposition: the problem,
  the alternatives, the choice and why. The code is quoted into it as the evidence that makes the
  claims checkable. "Literate" is about what is being said — the code is what the saying produces.
- A program is a piece of literature addressed to human beings (Knuth): *"The main idea is to
  treat a program as a piece of literature, addressed to human beings rather than to a
  computer."* One source, two products — **tangle** for the machine, **weave** for the reader —
  and neither product is the original.
- **The order belongs to the reader.** The whole point of named references is that the text can
  be arranged in the order the design is understood, not the order the machine runs it (noweb:
  *"tools let you arrange the parts of a program in any order and extract documentation and code
  from the same source file"*). Where a fragment is declared — before or after it is first used —
  is part of that arrangement, and the tool does not vote (D18).
- **Chunks are parts of sentences and paragraphs, not of files.** A fragment exists because a
  section of the argument needed a name for something. When a chunk name and a function name
  compete, the chunk is usually the coarser thing, because it belongs to a thought.
- **Reading front to back is the contract**: idea → shape → steps → details. `lp` checks the
  mechanism only (references resolve, no cycles, generated files equal the text). Whether a
  section states a thought, whether the order suits a reader, whether the prose is *true* — none
  of that is checkable, and it is what [`../SKILL.md`](../SKILL.md) is for.
- **In an agent workflow** this is the point: the exposition is the complete context for the code
  (nothing is implemented that the text does not explain), and the checks are what stop the two
  from drifting. Writing prose is no longer the expensive part of literate programming — knowing
  what is true, and saying it clearly, is.

## The case against, in its strongest form

Keep these; they are the reasons this stance has to be argued rather than assumed.

1. **"It is over-commenting, and the comments drift."** Names, small functions, types and tests
   carry intent in a modern language; prose adds little and can lie. **Conceded where it is
   right**: the payoff falls as the language's expressive power rises, so the article earns its
   keep where *order and structure* are the difficulty — algorithms, protocols, tooling,
   bootstrapping, teaching — and in a mature codebase it earns it as explanation of *why*, not
   *what*. **Not conceded**: drift. In `lp` the drift is a check failure, not a matter of
   discipline.
2. **"Tooling friction is why WEB and CWEB stayed niche."** An extra tool between the author and
   the compiler, no editor support, and diagnostics that point at generated code. **Answered by**
   `lp watch` (only changed bytes are rewritten), chunk-level provenance (`lp map`, `lp explain`)
   and `--check`. **Conceded**: it is still another tool, and a fresh clone has to bootstrap.
3. **"Reading code just got cheap."** If an agent can read ordinary source, what does the article
   buy? **Answered**: the *why*, which was never in the code, and a single source that cannot
   drift. **Conceded**: if all you ever do is modify code and never explain it to anyone, the
   article is overhead — that is a claim about the work, not about the tool.
4. **"Generated prose can be confidently wrong."** A plausible paragraph contradicting its chunk
   is worse than no paragraph, because the next reader stops looking at the code. **Answered**:
   the enforced invariants and the read-it-back rule exist for exactly this; **conceded**: the
   risk lands on the writer, and no check catches it.
5. **"It does not fit multi-writer, PR-diff-centred teams."** Also true: the argumentative
   structure and the review flow pull in different directions. This document's audience is the
   author and the agent working alongside them, not a review queue.
6. **The historical counter-fact.** What actually won was generated documentation (Javadoc,
   rustdoc) and notebooks; strict tangling stayed a niche. That is an argument about adoption, not
   about correctness — and the reason the position here is "the document is the source" rather
   than "everyone should do this".

## Evidence

| Kind | Examples |
| --- | --- |
| Measured, reproducible | adoption history (WEB/CWEB niche, noweb in dozens of languages for decades, notebooks dominating data science); `typst-unlit` clobbering line numbers; `lp`'s own numbers (full tangle 3–7 ms, whole-repo ownership walk 0.82 s, 49 tests) |
| Reasoned testimony | Knuth, Ramsey, Nørmark, Silver, apiad, Anticodians — decades of practice, no control groups |
| **Not found** | any reproducible study showing literate programming reduces defects or maintenance cost. Knuth claims it, second-hand posts repeat it. Treat it as **unverified**, not as fact. |

## Sources

- Knuth, *Literate Programming* (CSLI, 1992) and his definition page: <https://www-cs-faculty.stanford.edu/~knuth/lp.html>
- Knuth, "Literate programming", *The Computer Journal* 27(2):97–111, 1984: <https://academic.oup.com/comjnl/article-abstract/27/2/97/343244>
- Norman Ramsey, noweb: <https://www.cs.tufts.edu/~nr/noweb/>; "Literate Programming Simplified", *IEEE Software* 11(5):97–105, 1994: <https://www.cs.tufts.edu/~nr/cs257/archive/literate-programming/04-noweb.pdf>
- Kurt Nørmark, "Literate Programming — Issues and Problems": <https://people.cs.aau.dk/~normark/litpro/issues-and-problems.html>
- Nik Silver, "Literate programming, part 2: Problems and challenges": <https://niksilver.com/2019/10/22/literate-programming-part-2-problems-and-challenges/>
- Anticodians, "The End of Literate Programming": <https://anticodians.org/2024/12/04/the-end-of-literate-programming/>
- apiad, "The Best Way to Vibe Code is Literate Programming": <https://blog.apiad.net/p/the-best-way-to-vibe-code-is-literate>
- "A Literate Programming Environment for Human and Machine Agents" (arXiv 2608.24644): <https://arxiv.org/pdf/2608.24644>
````)



= Appendix: what else the document produces

== The package

Everything above is written with `chunk`, `file` and `rule`. They are not built into the
tool: the package that defines them is produced by this document, because the document
has to be *evaluable*, not merely printable — `typst compile` reads the same
declarations the tool reads. The consequence is an order: the document cannot be
evaluated before the package exists on disk, and that is what the seed is for. A fresh
clone runs the seed once, and needs it again only when the tool stops working.

#file("lit/lp.typ", ````typst
// lp.typ — declare chunks for the `lp` tool.
//
// A chunk is written by calling `chunk` (a fragment, referenced as <<name>>) or
// `file` (a chunk whose name is the output path, i.e. a root). The code block is
// passed as the argument, so the declaration carries everything the tool needs —
// name, language, text — and the tool never has to read the source to find out
// what a chunk is.
//
//   #import "lp.typ": chunk, file
//
//   #chunk("imports", ```rust
//   use std::fmt;
//   ```)
//
//   #file("src/main.rs", ```rust
//   <<imports>>
//   ```)
//
// Rendering lives here too, so the document does not need show rules: a chunk
// shows up as a titled block with its references marked.

// A reference line is indentation + <<name>>. The indentation is part of what a
// reference *means*: it decides how the expanded chunk is laid out when tangled,
// so the woven page has to show it — otherwise the document lies about the code.
#let ref-re = regex("^(\\s*)<<([^<>]+)>>\\s*$")

// The escape: a line that starts with `@` is a reference only to the eye. Tangling
// writes it out as `<<name>>`, so a document can quote the syntax it is written in
// (ADR D17).
#let esc-re = regex("^(\\s*)@<<([^<>]+)>>\\s*$")

/// The indentation a reference line contributes to the expanded chunk, or "" when
/// the line is not a reference. The renderer below uses it too, so this is the
/// implementation rather than a helper kept alive for a test.
#let ref-indent(line) = {
  let m = line.match(ref-re)
  if m == none { "" } else { m.captures.at(0) }
}

/// Ref marking is cosmetics, so a show rule is fine here — the *declarations*
/// below carry the semantics, and they do not depend on any show rule running.
#let rule(body) = {
  show raw.where(block: true): it => {
    let out = none
    for line in it.lines {
      let escaped = line.text.match(esc-re)
      let m = line.text.match(ref-re)
      let piece = if escaped != none {
        raw(escaped.captures.at(0) + "<<" + escaped.captures.at(1) + ">>")
      } else if m == none {
        line.body
      } else {
        raw(ref-indent(line.text)) + text(fill: rgb("#0a6"))[⟪#m.captures.at(1)⟫]
      }
      out = if out == none { piece + linebreak() } else { out + piece + linebreak() }
    }
    out
  }
  body
}

#let tile(name, lang, code) = block(
  breakable: true,
  width: 100%,
  inset: 8pt,
  radius: 3pt,
  fill: luma(238),
)[
  #text(size: 0.85em, weight: "bold", fill: luma(60))[⟪#name⟫]
  #h(0.6em)
  #text(size: 0.7em, fill: luma(120))[#if lang != none { lang }]
  #v(4pt)
  #code
]

// A fence without an info string has no `lang` field at all. The tag is data rather than
// a promise (ADR D18): missing means "not declared", and the tool records nothing.
#let lang-of(code) = code.at("lang", default: none)

/// A named fragment: referenced as `<<name>>`, written nowhere on its own.
#let chunk(name, code) = {
  [#metadata((lp: "chunk", name: name, lang: lang-of(code), text: code.text))<lp-decl>]
  tile(name, lang-of(code), code)
}

/// A root chunk: the name is the path it is tangled to.
#let file(path, code) = {
  [#metadata((lp: "file", name: path, lang: lang-of(code), text: code.text))<lp-decl>]
  tile(path, lang-of(code), code)
}
````)

== The build environment

The toolchain belongs to the program: without typst there are no declarations to read,
and without cargo there is no binary. It sits in an appendix rather than at the opening
because nothing in the design depends on it, but it is *in* the document rather than
beside it — the environment is a decision like any other, and it changes when a
dependency changes.

One thing here is both an output and tracked, and the reason is not taste: nix refuses to
evaluate a flake whose files are not in git, so the environment cannot be produced by a
tool that needs the environment to run. `flake.nix` and `flake.lock` are therefore
declared here *and* kept in the index; `lp tangle --check` still guards the pair, so the
tracked copies cannot drift from this text.

#file("flake.nix", ````nix
{
  description = "literate — Typst-based literate programming for arbitrary target languages";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          # typst: weave + the tangle front end (`typst eval`)
          # python3: the throwaway spike in experiments/, not the product
          packages = with pkgs; [ cargo rustc rustfmt clippy typst python3 ];
        };
      });
    };
}
````)

== What this repository carries

`lp` treats its output directory as its own and refuses to guess: every file under it
is produced by a declaration or listed in the `.lpignore` of its directory. Here the
output directory is the repository root, so the list of what this document does not
produce is short — the document itself, the seed, the notes, the two one-line files
that point at the document, and the lock files cargo and nix maintain.

#file(".lpignore", ````
# What the working tree carries besides the document's output.
#
# Matching here means *protect* (ADR D10): every file under the output directory is
# either produced by a #file declaration or listed here, and this lists what the
# document does not produce. The output directory is the repository root.

# The example writes here: `examples/demo/literate.typ` produces Cargo.toml and src/,
# and its own .lpignore governs everything else in the directory. This pass does not
# manage that tree — a nested document's output is not this document's business.
/examples/demo/build

/.git
/.direnv
/.pi
/AGENTS.md
/Cargo.lock
/README.md
/agent-notes
/flake.lock
/lp.typ
/result
/seed
/target
````)

== What git is asked to ignore

The crate, the package, the example and the two control files above are all generated,
so none of them is tracked. What remains in git is the document, the seed, the notes,
and the two pointers.

#file(".gitignore", ````
# Everything here is generated from lp.typ by `lp tangle lp.typ --out .`.
# Tracked: README.md, AGENTS.md, lp.typ, seed/, agent-notes/.

/Cargo.toml
/Cargo.lock
/src/
/tests/
/lit/
/.agents/
/examples/
/.gitignore
/.lpignore
.lpmap.json
target/
result
.direnv/

# Artifacts of the archived experiments in agent-notes/experiments: they are runs,
# not evidence.
*.pdf
*.png
out/
````)

== The example

`examples/demo/` is this tool used on a small crate: one fragment shared by two files,
three tangled files, a woven PDF, and a real rustc error translated back to the chunk
it came from. It is part of the document because it is the loud half of the claim:
`run.sh` fails when the tool stops working, and it runs alongside the tests.

#file("examples/demo/literate.typ", ````typst
#import "../../lit/lp.typ": chunk, file, rule
#show: rule

#set page(width: 15cm, height: auto, margin: 2cm)
#set text(size: 10pt)

= A multi-file crate, written as one document

This document is a normal Typst file — `typst compile examples/demo/literate.typ`
renders it. It is also the only source of a small Rust crate: every `#file(...)`
declaration names a real file to write when you run

```sh
lp tangle examples/demo/literate.typ --out examples/demo/build
```

Text like this never reaches the generated code. `#chunk("name", …)` declares a
fragment and chunks pull each other in with `<<name>>`. The order below is a
choice: the three files first, as skeletons that name what they need, then each
piece in the section that explains it. Pieces first and assembly last would be
just as legitimate — the argument decides, not the tool — and this document says
so in its first paragraph because a reader should know which shape they are in.

== The manifest

The crate is its own workspace so the surrounding repository's `Cargo.toml`
does not claim it.

#file("Cargo.toml", ```toml
[package]
name = "lp-demo"
version = "0.0.0"
edition = "2024"

# `lp` output is standalone; keep it out of the parent workspace.
[workspace]
```)

== The library

Two thirds of the crate: a banner comment it shares with the binary, and one
module. Neither is spelled out here — the sections below do that, in the order a
reader wants them.

`` `<<math-items>>` `` sits inside a module, so its two chunks are indented by four
spaces on the way out:

#file("src/lib.rs", ```rust
@<<crate-preamble>>

pub mod math {
    @<<math-items>>
}
```)

== The binary

The entry point: the same banner, the library's module, and whatever `main`
prints.

#file("src/main.rs", ```rust
@<<crate-preamble>>

use lp_demo::math;

fn main() {
    @<<print-results>>
}
```)

== The shared preamble

Both crate roots want the same banner comment at the top. It is not something
`lp` injects: the tool writes exactly the chunks you give it, nothing else. This
is just a chunk that two different root chunks happen to pull in — the same text
in two files, written once:

#chunk("crate-preamble", ```rust
//! generated by lp from literate.typ — edit the document, not this file
```)

== The module body

The module has two functions, declared as two separate `#chunk("math-items", …)`
blocks. Tangling concatenates declarations sharing a name, in document order, the
way noweb and org-babel do. The first one:

#chunk("math-items", ```rust
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
```)

and the second one, which the reader meets right where it belongs:

#chunk("math-items", ```rust
pub fn square(x: i32) -> i32 {
    x * x
}
```)

== What `main` prints

#chunk("print-results", ```rust
println!("add(2, 3) = {}", math::add(2, 3));
println!("square(5) = {}", math::square(5));
```)

== Running the result

```sh
lp tangle examples/demo/literate.typ --out examples/demo/build
cargo run --quiet --manifest-path examples/demo/build/Cargo.toml
```

```
add(2, 3) = 5
square(5) = 25
```

== Who owns that directory

`examples/demo/build/.lpignore` declares it as ours: every file in there that no
chunk produces gets removed, and the ones listed in the file are left alone —
cargo's `target/` and `Cargo.lock`, the woven PDF, the PNGs. Delete a root chunk
here and its file follows, instead of lingering for `cargo` to compile.

The rule is simple: point `--out` at a directory and that whole directory is
`lp`'s. Every file in it must be either produced by a chunk or declared in an
`.lpignore`. Anything else is an error — `lp tangle` fails and names it — and the
two ways out are to declare it, or to delete it on purpose with
`lp unaccounted --delete`. `lp` never removes anything by itself.

== When it breaks

If that binary stops compiling, the error is reported against the *generated*
file — `src/main.rs:6:5: cannot find function ...`. `lp` records which chunk
produced every generated line, so the diagnostic can be translated back:

```sh
cargo build --manifest-path examples/demo/build/Cargo.toml --message-format=short 2>&1 \
  | lp explain --out examples/demo/build
```

That is the difference between this and a preprocessor that only knows how to
dump text: the generated code stays accountable to the prose it came from.
````)

#file("examples/demo/run.sh", ````bash
#!/usr/bin/env bash
# The whole flow: tangle, build and run the result, weave, drift check, and
# translating a real rustc error back into the document.
# Run with: nix develop -c examples/demo/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

LP=(cargo run --quiet --)
DOC=examples/demo/literate.typ
OUT=examples/demo/build

echo "== tangle =="
"${LP[@]}" tangle "$DOC" --out "$OUT"

echo "== run the tangled crate =="
cargo run --quiet --manifest-path "$OUT/Cargo.toml" > "$OUT/run.txt"
diff -u examples/demo/expected.txt "$OUT/run.txt" && echo "output matches the document"

echo "== weave (PDF in $OUT) =="
typst compile --root . "$DOC" "$OUT/demo.pdf"

# A reference line's indentation decides the indentation of the expanded chunk, so
# the woven document has to show it (regression: it used to render flush left).
echo "== weave: references keep their indentation =="
indent=$(typst eval '{ import "lit/lp.typ": ref-indent; ref-indent("    <<print-results>>") }')
if [ "$indent" != '"    "' ]; then
    echo "FAIL: reference indentation is lost when weaving (got $indent)" >&2
    exit 1
fi
echo "reference indent survives: $indent"

echo "== drift check =="
"${LP[@]}" tangle "$DOC" --out "$OUT" --check

echo "== which chunk produced src/main.rs:6 =="
"${LP[@]}" map --file src/main.rs --line 6 --out "$OUT"

echo "== translate a real rustc error =="
sed -i 's/math::add(2, 3)/math::ad(2, 3)/' "$OUT/src/main.rs"
cargo build --manifest-path "$OUT/Cargo.toml" --message-format=short 2>&1 | "${LP[@]}" explain --out "$OUT" || true

echo "== restore =="
"${LP[@]}" tangle "$DOC" --out "$OUT" > /dev/null
"${LP[@]}" tangle "$DOC" --out "$OUT" --check && echo "document and generated code agree"
````)

#file("examples/demo/expected.txt", ````
add(2, 3) = 5
square(5) = 25
````)

#file("examples/demo/build/.lpignore", ````
# This directory belongs to lp: a file here that no chunk produces is removed.
# These are the ones other tools own, plus the weave output.
Cargo.lock
target/
*.pdf
*.png
run.txt
````)

= Appendix: how this document is worked on

== Starting from nothing

A fresh clone holds five things: this document, the seed, the notes, the two one-line
files that point here — and `flake.nix` with its lock, which nix insists on finding in git
before it will evaluate anything. Everything else is produced by tangling:

The seed is a whole older generation — a built crate, the package it was written with,
and its devshell — so the first move is to lay it down. It covers the one thing this
document cannot produce for itself: the package has to exist on disk before the document
can be evaluated at all, because the document imports it.

```sh
cp -r seed/. .
nix develop -c cargo build
nix develop -c ./target/debug/lp tangle lp.typ --out .
nix develop -c cargo test
```

The third command is the interesting one: the older lp reads the declarations here and
writes this generation over itself — crate, package, example, skill, control files. The
seed is then just a directory again, and it stays untouched until someone decides the
current generation should become the next seed.

After that the loop is the ordinary one: edit this document, tangle, test. While writing,

```sh
nix develop -c ./target/debug/lp watch lp.typ --out . --check-cmd 'cargo build --message-format=short'
```

`tests/self.rs` is what keeps the loop honest: the binary this document builds has to be
able to reproduce the sources it was built from, so hand-editing `src/` or `tests/` fails
a test instead of quietly working.

== Replacing the seed

The seed only ever reads, and it is only replaced on purpose: when this document starts
using syntax the seed cannot read — which has already happened once, with the escape in
D17 — the current generation becomes the next seed. It is a copy, not a build step:

```sh
cp -f Cargo.toml Cargo.lock flake.nix flake.lock seed/
rm -rf seed/src seed/tests seed/lit
mkdir -p seed/src seed/tests seed/lit
cp src/*.rs seed/src/
cp tests/*.rs seed/tests/
cp lit/lp.typ seed/lit/
```

The seed is then one generation behind again, which is all it has to be: old enough to
read this document, complete enough to be built.

== The rules

These are not style preferences; each one was paid for. The decisions behind them are in
`agent-notes/decisions/`.

- **Elegance is an admission requirement.** If the only way to build a feature is to
  search source text heuristically, or to parse Typst a second time, the feature is not
  built. That is how line-number mapping, label-as-chunk-name and static analysis of
  Typst were dropped.
- **The tool never parses Typst.** Its whole understanding is one `typst eval` reading the
  declaration stream.
- **No line numbers.** Typst's script layer has no source positions; provenance is
  chunk-level, and pretending otherwise would mean re-parsing.
- **Orthogonality.** No knowledge of any target language in the algorithms; language
  differences are data (the fence tag), never code.
- **Generated files stay out of git**, and only this document is edited: the crate, the
  package, the example, the control files. Two things are declared here and tracked anyway,
  for bootstrap reasons: the seed (a frozen copy of an older generation) and `flake.nix`
  with its lock (nix will not evaluate a flake that is not in git). `--check` guards both.
- **An error points at a declaration**, never at a bare string: which chunk, and which
  line inside it.
- **Unexplained files are errors, deletion is explicit.** Everything under the output
  directory is produced by a declaration or listed in a `.lpignore`; `lp` never deletes
  anything by itself.
- **Only changed bytes are written, and a document that does not evaluate is not
  tangled.** The previous good output stays until the document is valid again.
- **The order is free and the language tag is data** (D18). Thought-first, progressive
  disclosure and logical consistency cannot be checked by a tool, so they are the
  writer's job — the skill in the appendix above is the attempt to keep that promise.
- **Dependencies are chosen from mature crates** (D7); every new one gets a line saying
  why. `typst` is a hard dependency of tangling (`LP_TYPST`, then `PATH`).

== The skill

`lp.typ` also produces the agent skill under `.agents/skills/literate-programming/`: the
discipline for writing in this document, in a form an agent loads by itself. It is part
of the document for the reason everything else is — a rule that lives outside the thing it
governs is a rule that drifts.
