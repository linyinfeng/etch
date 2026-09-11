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
    /// Translate a line of a generated file back to the .typ document
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
