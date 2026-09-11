mod diag;
mod explain;
mod map;
mod parse;
mod sweep;
mod tangle;
mod watch;

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
        #[arg(long, conflicts_with = "prune")]
        check: bool,
        /// Delete files a previous pass generated that no chunk produces any more
        #[arg(long)]
        prune: bool,
    },
    /// Translate a line of a generated file back to the .typ document
    Map {
        /// Generated file, relative to --out (a unique basename also works)
        #[arg(long, conflicts_with = "typ")]
        file: Option<String>,
        /// Reverse mode: list the generated lines that came from this document
        #[arg(long, conflicts_with = "file")]
        typ: Option<String>,
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
        /// Delete files a previous pass generated that no chunk produces any more
        #[arg(long)]
        prune: bool,
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
        Command::Tangle {
            docs,
            out,
            check,
            prune,
        } => {
            let docs = docs
                .iter()
                .map(|path| Doc::load(path))
                .collect::<Result<Vec<_>, _>>()?;
            let outcome = tangle::run(&docs, &out, check, prune)?;
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
            for rel in &outcome.pruned {
                println!("pruned {rel}");
            }
            if !outcome.pruned.is_empty() {
                for root in &outcome.managed {
                    eprintln!("managed {root} (by .lpignore)");
                }
            }
            for rel in &outcome.orphans {
                eprintln!(
                    "orphan {rel} (no chunk produces it any more; run `lp tangle --prune` to delete it)"
                );
            }
            for line in &outcome.stale {
                eprintln!("{line}");
            }
            for warning in &outcome.warnings {
                eprintln!("warning: {warning}");
            }
            Ok(i32::from(!outcome.stale.is_empty()))
        }
        Command::Watch {
            docs,
            out,
            debounce,
            check_cmd,
            prune,
        } => {
            watch::run(watch::Options {
                docs,
                out,
                debounce: std::time::Duration::from_millis(debounce),
                check_cmd,
                prune,
            })?;
            Ok(0)
        }
        Command::Map {
            file,
            typ,
            line,
            out,
        } => {
            let map = map::LpMap::read(&out)?;

            if let Some(doc) = typ {
                let mut hits = 0;
                for (rel, entry) in &map.files {
                    if entry.typ != doc && !entry.typ.ends_with(doc.as_str()) {
                        continue;
                    }
                    for [out_line, typ_line] in &entry.lines {
                        if *typ_line == line {
                            println!("{rel}:{out_line}");
                            hits += 1;
                        }
                    }
                }
                if hits == 0 {
                    eprintln!("note: nothing in the generated files came from {doc}:{line}");
                }
                return Ok(0);
            }

            let Some(file) = file else {
                return Err(LpError::plain(
                    "lp map needs --file (generated line) or --typ (reverse)",
                ));
            };
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

    for error in doc.errors.iter().take(3) {
        match &error.range {
            Some(range) => {
                let line = doc.text[..range.start].matches('\n').count() + 1;
                let err = LpError::at(
                    &doc.src,
                    range.clone(),
                    error.message.clone(),
                    "syntax error",
                );
                eprintln!(
                    "{}:{line}: {:?}",
                    doc.path.display(),
                    miette::Report::new(err)
                );
            }
            None => eprintln!("{}: {}", doc.path.display(), error.message),
        }
    }

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
