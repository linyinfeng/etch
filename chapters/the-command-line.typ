#import "@local/lp:0.1.0": chunk, file

= The command line, and what each command is for

This is the file that turns the library into a program. It has two jobs and no third:
describe the surface, so that `lp --help` is the contract and clap writes it; and translate a
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
    <<main: map>>
    <<main: explain>>
    <<main: list>>
    <<main: metadata>>
    <<main: unaccounted>>
}

fn main() {
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

fn run() -> Result<i32, LpError> {
    match Cli::parse().command {
        <<main: tangle, and what it reports>>
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

fn list(docs: &[PathBuf]) -> Result<(), LpError> {
    <<main: plan, and who is referenced>>

    <<main: one row per declaration>>

    <<main: the outputs at the end>>
    Ok(())
}
````)

== The surface

The declarations are the contract, so they are also where the help text lives: the `help` attributes in this
file are `lp --help`. Each command gets its own fragment, because each one is a promise about what the tool
does.

#chunk("main: the modules, and what they are called", ````rust
mod book;
mod diag;
mod embedded;
mod explain;
mod map;
mod metadata;
mod status;
mod tangle;
mod weave;

use std::collections::BTreeSet;
use std::io::Read;
use std::path::PathBuf;

use clap::{ArgGroup, Parser, Subcommand};

use diag::LpError;
````)

#chunk("main: the surface, as clap sees it", ````rust
#[derive(Parser)]
#[command(name = "lp", version, about = "Typst-based literate programming")]
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
#[command(about = "Render a document with the package this tool carries")]
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
    #[arg(help = "Documents to tangle, e.g. book/lp.typ")]
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
