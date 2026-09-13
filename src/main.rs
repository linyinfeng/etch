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

#[derive(Parser)]
#[command(name = "etch", version, about = "Typst-based literate programming")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    #[command(about = "Render a document with Typst")]
    Weave {
        doc: PathBuf,
        output: Option<PathBuf>,
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        extra: Vec<String>,
    },
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
    #[command(name = "self", about = "Work with the book this binary carries")]
    Itself {
        #[command(subcommand)]
        method: SelfMethod,
    },
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
    #[command(about = "Rewrite diagnostics so they name the chunk that produced the line")]
    Explain {
        #[arg(long)]
        out: Option<PathBuf>,
    },
    #[command(about = "List the chunks a document declares")]
    List { doc: PathBuf },
    #[command(about = "Print the declarations a document hands the tool")]
    Metadata {
        #[arg(required = true)]
        docs: Vec<PathBuf>,
    },
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
}

fn main() {
    let named = std::env::var("ETCH_LOG").unwrap_or_default();
    let level = match named.to_lowercase().as_str() {
        "off" => tracing::Level::ERROR,
        "error" => tracing::Level::ERROR,
        "warn" => tracing::Level::WARN,
        "debug" => tracing::Level::DEBUG,
        "trace" => tracing::Level::TRACE,
        _ => tracing::Level::INFO,
    };
    tracing_subscriber::fmt()
        .with_max_level(level)
        .with_target(false)
        .with_writer(std::io::stderr)
        .with_ansi(std::io::IsTerminal::is_terminal(&std::io::stderr()))
        .init();
    #[cfg(unix)]
    unsafe {
        libc::signal(libc::SIGPIPE, libc::SIG_DFL);
    }
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
        Command::Weave { doc, output, extra } => weave::run(&doc, output.as_deref(), &extra),
        Command::Extract { format, file, out } => {
            let files = crate::book::extract(&file, &format, &out)?;
            debug!("wrote {files} files of the book to {}", out.display());
            Ok(0)
        }
        Command::Itself { method } => match method {
            SelfMethod::Book { out } => {
                let files = embedded::book(&out)?;
                debug!("wrote {files} files of the book to {}", out.display());
                Ok(0)
            }
            SelfMethod::Read { format } => {
                let path = embedded::read(&format)?;
                println!("{}", path.display());
                Ok(0)
            }
            SelfMethod::Prove { dir } => embedded::prove(&dir),
        },
        Command::Tangle { docs, out, check } => {
            let out = out_dir(out, &docs);
            let outcome = tangle::run(&docs, &out, check)?;
            let verdict = i32::from(!outcome.drifted.is_empty() || !outcome.missing.is_empty());

            if outcome.carried > 0 {
                let plural = if outcome.carried == 1 { "" } else { "s" };
                debug!("carried {} book file{plural}", outcome.carried);
            }
            if outcome.removed > 0 {
                let plural = if outcome.removed == 1 { "" } else { "s" };
                debug!("removed {} stale book file{plural}", outcome.removed);
            }
            for output in &outcome.changed {
                debug!(
                    "wrote  {}  ({} lines, {})",
                    output.root,
                    output.lines,
                    output.lang.as_deref().unwrap_or("-")
                );
            }
            for output in &outcome.unchanged {
                debug!("ok     {}", output.root);
            }
            for drift in &outcome.drifted {
                let origin = match (&drift.chunk, drift.line) {
                    (Some(chunk), Some(line)) => format!(" (line {line}, in chunk ⟪{chunk}⟫)"),
                    (None, Some(line)) => format!(" (line {line})"),
                    _ => String::from(" (file differs)"),
                };
                debug!("STALE  {}{origin}", drift.root);
            }
            for root in &outcome.missing {
                debug!("STALE  {root} (file missing)");
            }
            for name in &outcome.unreferenced {
                debug!("chunk ⟪{name}⟫ is never referenced");
            }
            for name in &outcome.wordless {
                debug!("chunk ⟪{name}⟫ is declared without a language");
            }
            for group in &outcome.unaccounted {
                for entry in &group.entries {
                    debug!("unaccounted  {}", map::join(&group.dir, entry));
                }
            }

            machine(
                "tangle",
                json!({
                    "documents": docs.iter().map(|doc| doc.display().to_string()).collect::<Vec<_>>(),
                    "changed": outcome.changed,
                    "unchanged": outcome.unchanged,
                    "drifted": outcome.drifted,
                    "missing": outcome.missing,
                    "unreferenced": outcome.unreferenced,
                    "wordless": outcome.wordless,
                    "unaccounted": outcome.unaccounted,
                }),
            )?;
            Ok(verdict)
        }
        Command::Plan { docs, out } => {
            let out = out_dir(out, &docs);
            let outcome = tangle::inspect(&docs, &out)?;

            for output in &outcome.changed {
                debug!(
                    "would write  {}  ({} lines, {})",
                    output.root,
                    output.lines,
                    output.lang.as_deref().unwrap_or("-")
                );
            }
            for output in &outcome.unchanged {
                debug!("nothing to do  {}", output.root);
            }
            for name in &outcome.unreferenced {
                debug!("chunk ⟪{name}⟫ is never referenced");
            }
            for name in &outcome.wordless {
                debug!("chunk ⟪{name}⟫ is declared without a language");
            }
            for group in &outcome.unaccounted {
                for entry in &group.entries {
                    debug!("unaccounted  {}", map::join(&group.dir, entry));
                }
            }

            machine(
                "plan",
                json!({
                    "documents": docs.iter().map(|doc| doc.display().to_string()).collect::<Vec<_>>(),
                    "changed": outcome.changed,
                    "unchanged": outcome.unchanged,
                    "unreferenced": outcome.unreferenced,
                    "wordless": outcome.wordless,
                    "unaccounted": outcome.unaccounted,
                }),
            )?;
            Ok(0)
        }
        Command::Map {
            file,
            typ,
            line,
            out,
        } => {
            let out = out_dir(out, &[]);
            let maps = map::EtchMap::read_all(&out)?;

            if let Some(chunk) = typ {
                let mut hits: Vec<(String, usize)> = Vec::new();
                for (dir, map) in &maps {
                    for (name, file) in &map.files {
                        for run in &file.runs {
                            if run.chunk == chunk {
                                for line in run.first..=run.last {
                                    hits.push((map::join(dir, name), line));
                                }
                            }
                        }
                    }
                }
                for (file, line) in &hits {
                    debug!("{file}:{line}");
                }
                if hits.is_empty() {
                    debug!("nothing in the generated files came from chunk ⟪{chunk}⟫");
                }
                let places: Vec<serde_json::Value> = hits
                    .iter()
                    .map(|(file, line)| json!({"file": file, "line": line}))
                    .collect();
                machine("map", json!({"chunk": chunk, "hits": places}))?;
                return Ok(0);
            }

            let (file, line) = match (file, line) {
                (Some(file), Some(line)) => (file, line),
                _ => {
                    return Err(EtchError::plain("etch map takes one direction").with_help(
                        "use `etch map --file src/main.rs --line 42` for a generated line, or `etch map --typ <chunk>` the other way",
                    ))
                }
            };
            let (dir, name, entry) = map::resolve_all(&maps, &file)?;
            let rel = map::join(dir, name);
            let Some((run, offset)) = entry.locate(line) else {
                return Err(EtchError::plain(format!(
                    "{rel}:{line}: no map knows this file"
                )));
            };

            debug!("chunk ⟪{}⟫, line {offset} of it", run.chunk);
            debug!("    find it with: rg '#chunk(\"{}\")'", run.chunk);
            machine(
                "map",
                json!({
                    "file": rel,
                    "line": line,
                    "chunk": run.chunk,
                    "offset": offset,
                    "exact": run.first <= line && line <= run.last,
                }),
            )?;
            Ok(0)
        }
        Command::Explain { out } => {
            let out = out_dir(out, &[]);
            let mut input = String::new();
            std::io::stdin()
                .read_to_string(&mut input)
                .map_err(|e| EtchError::plain(e.to_string()))?;
            let mapped = explain::run(&out, &input)?;
            if mapped == 0 {
                debug!("no diagnostic line matched any map");
            }
            Ok(0)
        }
        Command::List { doc } => {
            list(std::slice::from_ref(&doc))?;
            Ok(0)
        }
        Command::Metadata { docs } => {
            let typst = metadata::binary()?;
            let declarations = metadata::declarations(&typst, &docs)?;

            for declaration in &declarations {
                debug!(
                    "{:<6} {:<28} {:<8} {}",
                    declaration.etch,
                    declaration.name,
                    declaration.lang.as_deref().unwrap_or("-"),
                    declaration.text.lines().next().unwrap_or("")
                );
            }

            machine("metadata", json!({ "declarations": declarations }))?;
            Ok(0)
        }
        Command::Unaccounted { docs, out, delete } => {
            let out = out_dir(out, &docs);
            let plan = tangle::plan(&docs)?;
            let produced = tangle::produced(&plan);
            let listed = status::unaccounted(&out, &produced)?;

            if listed.is_empty() {
                debug!(
                    "{}: every file under the output directory is accounted for",
                    out.display()
                );
            }
            for group in &listed {
                let label = if group.dir.is_empty() {
                    ".".to_string()
                } else {
                    group.dir.clone()
                };
                debug!("{label}/ — {} nothing accounts for:", group.entries.len());
                for entry in &group.entries {
                    debug!("  {}", map::join(&group.dir, entry));
                }
            }

            let deleted = if delete {
                status::delete(&out, &produced)?
            } else {
                Vec::new()
            };
            for relative in &deleted {
                debug!("deleted {relative}");
            }

            let verdict = i32::from(!listed.is_empty() && !delete);
            machine(
                "unaccounted",
                json!({"unaccounted": listed, "deleted": deleted}),
            )?;
            Ok(verdict)
        }
    }
}

fn list(docs: &[PathBuf]) -> Result<(), EtchError> {
    let plan = tangle::plan(docs)?;
    let set = tangle::ChunkSet::new(&plan.blocks);
    let referenced = &plan.referenced;

    let declarations: Vec<serde_json::Value> = plan
        .blocks
        .iter()
        .map(|block| {
            json!({
                "kind": if block.root { "file" } else { "chunk" },
                "name": block.name,
                "lang": block.lang,
                "referenced": referenced.contains(&block.name) || block.root,
            })
        })
        .collect();
    machine(
        "list",
        json!({
            "documents": docs.iter().map(|doc| doc.display().to_string()).collect::<Vec<_>>(),
            "declarations": declarations,
            "outputs": set.roots(),
        }),
    )?;

    for doc in docs {
        debug!("{}", doc.display());
    }
    for block in &plan.blocks {
        let kind = if block.root { "file" } else { "frag" };
        let used = if referenced.contains(&block.name) || block.root {
            String::new()
        } else {
            "unreferenced".to_string()
        };
        debug!(
            "  {kind}  {:<28} {:<8} {}",
            format!("⟪{}⟫", block.name),
            block.lang.as_deref().unwrap_or("-"),
            used
        );
    }

    let roots = set.roots();
    debug!(
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

fn machine(command: &str, payload: serde_json::Value) -> Result<(), EtchError> {
    let mut fields = serde_json::Map::new();
    fields.insert("version".into(), serde_json::Value::from(1));
    fields.insert("command".into(), serde_json::Value::from(command));
    if let serde_json::Value::Object(rest) = payload {
        fields.extend(rest);
    }
    println!("{}", serde_json::Value::Object(fields));
    Ok(())
}
