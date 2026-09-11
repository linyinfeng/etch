mod diag;
mod explain;
mod map;
mod parse;
mod tangle;

use std::collections::BTreeSet;
use std::io::Read;
use std::path::{Path, PathBuf};

use clap::{Parser, Subcommand};

use diag::LpError;
use parse::Doc;

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
    /// Translate a line of a generated file back to the .typ document
    Map {
        /// Generated file, relative to --out (a unique basename also works)
        #[arg(long)]
        file: String,
        #[arg(long)]
        line: usize,
        #[arg(long, default_value = "out")]
        out: PathBuf,
    },
    /// Rewrite diagnostics so they point into the .typ document
    Explain {
        #[arg(long, default_value = "out")]
        out: PathBuf,
        /// Diagnostic format on stdin
        #[arg(long, default_value = "generic", value_parser = ["generic", "cargo"])]
        format: String,
    },
    /// List the chunks in a document, with their .typ lines
    List { doc: PathBuf },
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
            let docs = docs
                .iter()
                .map(|path| Doc::load(path))
                .collect::<Result<Vec<_>, _>>()?;
            let outcome = tangle::run(&docs, &out, check)?;
            for warning in &outcome.warnings {
                eprintln!("warning: {warning}");
            }
            Ok(i32::from(outcome.stale))
        }
        Command::Map { file, line, out } => {
            let map = map::LpMap::read(&out)?;
            let (rel, entry) = map::resolve(&map, &file)?;
            let Some([mapped_line, typ_line]) = entry.locate(line) else {
                return Err(LpError::plain(format!("{rel}:{line}: not in the line map")));
            };

            println!("{}:{typ_line}", entry.typ);
            if let Some(text) = std::fs::read_to_string(&entry.typ).ok().and_then(|doc| {
                doc.lines()
                    .nth(typ_line - 1)
                    .map(str::trim_end)
                    .map(str::to_string)
            }) {
                println!("    {text}");
            }
            if mapped_line != line {
                eprintln!(
                    "note: {rel}:{line} is blank or generated; nearest mapped line is {mapped_line}"
                );
            }
            Ok(0)
        }
        Command::Explain { out, format } => {
            let map = map::LpMap::read(&out)?;
            let mut input = String::new();
            std::io::stdin()
                .read_to_string(&mut input)
                .map_err(|e| LpError::plain(e.to_string()))?;
            let mapped = explain::run(&map, &format, &input)?;
            if mapped == 0 {
                eprintln!("note: no diagnostic line matched the line map");
            }
            Ok(0)
        }
        Command::List { doc } => {
            list(&doc)?;
            Ok(0)
        }
    }
}

fn list(path: &Path) -> Result<(), LpError> {
    let doc = Doc::load(path)?;
    let set = tangle::ChunkSet::new(&doc);
    let referenced: BTreeSet<String> = doc.blocks.iter().flat_map(tangle::refs_of).collect();

    println!("{}: {} chunks", doc.path.display(), doc.blocks.len());
    let mut blocks = doc.blocks.iter().collect::<Vec<_>>();
    blocks.sort_by_key(|block| block.fence_line);
    for block in blocks {
        let kind = if parse::is_root(&block.name) {
            "root"
        } else {
            "frag"
        };
        let used = if referenced.contains(&block.name) || parse::is_root(&block.name) {
            String::new()
        } else {
            "unreferenced".to_string()
        };
        println!(
            "  {kind}  {:<28} line {:>4}  {:<8} {}",
            format!("<{}>", block.name),
            block.fence_line,
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
                .map(|r| format!("<{r}>"))
                .collect::<Vec<_>>()
                .join(", ")
        }
    );
    Ok(())
}
