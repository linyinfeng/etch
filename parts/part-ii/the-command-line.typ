#import "../../package/lib.typ": chunk, file

= The command line, and what each command is for

This is the file that turns the library into a program. It has two jobs and no third:
describe the surface, so that `etch --help` is the contract and clap writes it; and translate a
command into calls on the modules the earlier chapters described, printing what happened and
choosing an exit status.

Nothing here decides anything about tangling, mapping or ownership. That is the point — the
surface is a table, and the table is small enough to read in one sitting, which is how a
reader finds out what the tool can do without reading the tool.

#file("src/main.rs", ````rust
<<main: self, what it can do>>

<<main: the modules, and what they are called>>

<<main: the surface, as clap sees it>>

#[derive(Subcommand)]
enum Command {
    <<main: weave>>
    <<main: extract>>
    <<main: self>>
    <<main: tangle>>
    <<main: plan>>
    <<main: map>>
    <<main: explain>>
    <<main: list>>
    <<main: metadata>>
    <<main: unaccounted>>
}

fn main() {
    <<main: the log>>
    <<main: a closed pipe is not a panic>>
    <<main: how an error is printed>>
    <<main: the exit status>>
}

fn out_dir(given: Option<PathBuf>, docs: &[PathBuf]) -> PathBuf {
    if let Some(path) = given {
        return path;
    }
    match docs.first().and_then(|doc| doc.parent()) {
        Some(dir) if !dir.as_os_str().is_empty() => dir.join("tangled"),
        _ => PathBuf::from("tangled"),
    }
}

fn run() -> Result<i32, EtchError> {
    match Cli::parse().command {
        <<main: tangle, and what it reports>>
        <<main: plan, which decides nothing>>
        <<main: the map arm>>

        <<main: map, in reverse>>

        <<main: map, forward>>

        <<main: map, the answer>>
        }
        <<main: explain, a filter on stdin>>
        <<main: list, one document>>
        <<main: metadata, the stream itself>>
        <<main: unaccounted, which needs a plan>>
    }
}

fn list(docs: &[PathBuf]) -> Result<(), EtchError> {
    <<main: plan, and who is referenced>>

    <<main: the same list, for a program>>

    <<main: one row per declaration>>

    <<main: the outputs at the end>>
    Ok(())
}

<<main: one document, for a program>>
````)

== The surface
The declarations are the contract, so they are also where the help text lives: the `help` attributes in this
file are `etch --help`. Each command gets its own fragment, because each one is a promise about what the tool
does.

The other half of that promise is where the two kinds of output go, and it is a rule rather than a flag.
Standard output is data: every command that answers a question writes exactly one JSON document there, and a
command that changes files writes one that says what it changed. Six commands answer that way — `tangle`,
`plan`, `map`, `list`, `metadata` and `unaccounted` — and the other five write their product there instead of
a report about it: `explain` echoes what it read with a note added, `self read` prints the path it opened,
`weave`, `extract` and `self book` write the file they were asked for and mention it only in the log, and
`self prove` lets nix print.
Nothing else is written to standard output — no table, no sentence, not even "wrote" — so a program reads it
without parsing anything, and a person pipes it into `jq`. Standard error is the log: what the tool did to the
disk at `INFO`, and what it looked at, plus
the report it would otherwise have printed, at `DEBUG`. `ETCH_LOG=debug` is how a person reads that report; the
readouts this book quotes — `ok`, `wrote`, `STALE`, the sentence `map` answers with — are those log lines.

Every document starts the same way — `version`, which is `1`, and `command`, which is the command's name —
so a consumer can tell at a glance what it is reading. What the fields carry is the data a program acts on: a
chunk, a line, a file, whether a mapping is exact. Prose stays prose, in the log, where nothing is expected to
take it apart, and the two are not two implementations: the same values are built once and rendered twice,
because a second spelling of the same fact is a second fact that can go its own way.

A failure is not a document. A command that could not answer exits non-zero, writes its report to standard
error, and leaves standard output empty — so a program can tell "the answer is empty" from "there is no
answer", the way the shell does for every filter on the machine. Bad news is not a failure: `unaccounted`
still exits 1 when something is unaccounted for, and it says so in the document rather than instead of it.

#chunk("main: the modules, and what they are called", ````rust
mod book;
mod diag;
mod disk;
mod embedded;
mod explain;
mod map;
mod metadata;
mod status;
mod tangle;
mod weave;

use std::io::Read;
use std::path::PathBuf;

use clap::{ArgGroup, Parser, Subcommand};
use serde_json::json;
use tracing::debug;

use diag::EtchError;
````)

#chunk("main: the surface, as clap sees it", ````rust
#[derive(Parser)]
#[command(name = "etch", version, about = "Typst-based literate programming")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}
````)

#chunk("main: extract", ````rust
#[command(about = "Take the book back out of a page this tool rendered")]
Extract {
    #[arg(long)]
    #[arg(help = "Which rendering to read")]
    format: String,
    #[arg(help = "The rendered page")]
    file: PathBuf,
    #[arg(long)]
    #[arg(help = "Directory to write the book into")]
    out: PathBuf,
},
````)

#chunk("main: self", ````rust
#[command(name = "self", about = "Work with the book this binary carries")]
Itself {
    #[command(subcommand)]
    method: SelfMethod,
},
````)

#chunk("main: self, what it can do", ````rust
#[derive(Subcommand)]
enum SelfMethod {
    #[command(about = "Write the book out, entire")]
    Book {
        #[arg(long)]
        #[arg(help = "Directory to write it into")]
        out: PathBuf,
    },
    #[command(about = "Weave the document this binary carries, then open it")]
    Read {
        #[arg(long, default_value = "pdf")]
        #[arg(help = "Which rendering to make")]
        format: String,
    },
    #[command(about = "Unpack the book, tangle it with this binary, and run the tree's own checks")]
    Prove {
        #[arg(help = "Directory to build the book in")]
        dir: PathBuf,
    },
}
````)

#chunk("main: weave", ````rust
#[command(about = "Render a document with Typst")]
Weave {
    doc: PathBuf,
    output: Option<PathBuf>,
    #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
    extra: Vec<String>,
},
````)

#chunk("main: tangle", ````rust
#[command(about = "Expand a .typ document into its source files")]
Tangle {
    #[arg(required = true)]
    #[arg(help = "Documents to tangle, e.g. book/etch.typ")]
    docs: Vec<PathBuf>,
    #[arg(long)]
    #[arg(
        help = "Directory the root chunk names resolve into (default: tangled/ next to the documents, or in the working directory for commands that take none)"
    )]
    out: Option<PathBuf>,
    #[arg(long)]
    #[arg(help = "Write nothing; fail if the generated files are out of date")]
    check: bool,
},
````)

`map` has two directions and they are a choice rather than a set of optional flags, so the choice is
clap's to enforce, in the declarations below: one required group names the two flags that pick a direction,
`requires` says that a file comes with a line, and a conflict says that a line beside a chunk name means
nothing. None of the three can be derived from the others, so all three are written out.
#chunk("main: plan", ````rust
#[command(about = "Print what a pass would do, without writing anything")]
Plan {
    #[arg(required = true)]
    #[arg(help = "Documents to plan for, e.g. book/etch.typ")]
    docs: Vec<PathBuf>,
    #[arg(long)]
    #[arg(
        help = "Directory the root chunk names resolve into (default: tangled/ next to the documents, or in the working directory for commands that take none)"
    )]
    out: Option<PathBuf>,
},
````)

#chunk("main: map", ````rust
#[command(about = "Name the chunk a generated line came from, or the lines a chunk produced")]
#[command(group(ArgGroup::new("what").required(true).multiple(false).args(["file", "typ"])))]
Map {
    #[arg(long, requires = "line")]
    #[arg(help = "A generated file, as the map names it: one direction, with --line")]
    file: Option<String>,
    #[arg(long, conflicts_with = "line")]
    #[arg(help = "A chunk name: the other direction, and no line to go with it")]
    typ: Option<String>,
    #[arg(long)]
    #[arg(help = "A line in that file, 1-based, as the map counts it")]
    line: Option<usize>,
    #[arg(long)]
    #[arg(
        help = "Directory the maps are in (default: tangled/, since this command names no document)"
    )]
    out: Option<PathBuf>,
},
````)

#chunk("main: explain", ````rust
#[command(about = "Rewrite diagnostics so they name the chunk that produced the line")]
Explain {
    #[arg(long)]
    out: Option<PathBuf>,
},
````)

#chunk("main: list", ````rust
#[command(about = "List the chunks a document declares")]
List { doc: PathBuf },
````)

`list` and `metadata` are the two commands that exist for the person debugging a document
rather than for the build. They answer the questions a reader of this document asks all the
time — which chunks exist, in what order, and what does Typst actually hand over — and they do
it without writing anything.

#chunk("main: metadata", ````rust
#[command(about = "Print the declarations a document hands the tool")]
Metadata {
    #[arg(required = true)]
    docs: Vec<PathBuf>,
},
````)

#chunk("main: unaccounted", ````rust
#[command(
    about = "List (or delete) files under the output directory that nothing accounts for"
)]
Unaccounted {
    #[arg(required = true)]
    #[arg(help = "Documents that decide what counts as produced")]
    docs: Vec<PathBuf>,
    #[arg(long)]
    out: Option<PathBuf>,
    #[arg(long)]
    #[arg(help = "Delete them: the explicit alternative to declaring them")]
    delete: bool,
},
````)
