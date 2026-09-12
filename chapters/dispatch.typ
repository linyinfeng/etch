#import "@local/lp:0.1.0": chunk

= Dispatch, one arm per promise

The surface ends at the argument parser; what happens to a parsed command is this chapter. Three things
are decided here and nowhere else: how an error becomes text and an exit status, which module each command
calls, and the one command that prints a view of its own instead of writing files.

Every error in this program is an `LpError`, and this is the only place it becomes text. The
report handler is installed once, so no module has to think about rendering; and the exit
status is 1 for every failure, which is all a shell needs to know.

A program that prints has one more way to end than the two below, and it is worth naming because it
looks like a crash: the reader on the other end of the pipe has gone away. Rust ignores `SIGPIPE`,
so a closed pipe does not kill the write — it makes it fail, and `println!` panics on a failed write.
That is how `lp list lp.typ | head` exits: one hundred and one, with a message about a broken pipe,
where every filter on the machine exits quietly. So the one handler this tool has anything to do with
is put back the way the shell expects it.

#chunk("main: a closed pipe is not a panic", ````rust
#[cfg(unix)]
unsafe {
    libc::signal(libc::SIGPIPE, libc::SIG_DFL);
}
````)

#chunk("main: how an error is printed", ````rust
let _ = miette::set_hook(Box::new(|_| {
    Box::new(miette::GraphicalReportHandler::new_themed(
        miette::GraphicalTheme::unicode(),
    ))
}));
````)

The commands that answer questions build their values once and then either print a table and a sentence, or
hand the same values here. There is one implementation of the envelope rather than one per command, because
the promise is that every machine document starts the same way — a version and the command that produced it —
and a promise made in five places is five promises. The version is a number to check, not a number to trust:
a consumer that does not know `1` should stop rather than guess at fields that may have moved.

#chunk("main: one document, for a program", ````rust
fn machine(command: &str, payload: serde_json::Value) -> Result<(), LpError> {
    let mut fields = serde_json::Map::new();
    fields.insert("version".into(), serde_json::Value::from(1));
    fields.insert("command".into(), serde_json::Value::from(command));
    if let serde_json::Value::Object(rest) = payload {
        fields.extend(rest);
    }
    println!("{}", serde_json::Value::Object(fields));
    Ok(())
}
````)

#chunk("main: the exit status", ````rust
match run() {
    Ok(code) => std::process::exit(code),
    Err(err) => {
        eprintln!("{:?}", miette::Report::new(err));
        std::process::exit(1);
    }
}
````)

== One arm per promise

Each arm is short on purpose: parse the arguments, call the module, print. Where an arm grows
a decision, that decision belongs in the module it calls, and the arm gets thinner or the
module gets a new function.

#chunk("main: tangle, and what it reports", ````rust
Command::Weave { doc, output, extra } => weave::run(&doc, output.as_deref(), &extra),
Command::Extract { format, file, out } => {
    let files = crate::book::extract(&file, &format, &out)?;
    println!("wrote {files} files of the book to {}", out.display());
    Ok(0)
}
Command::Itself { method } => match method {
    SelfMethod::Book { out } => {
        let files = embedded::book(&out)?;
        println!("wrote {files} files of the book to {}", out.display());
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
````)

Tangling is the one command with a *report* rather than a result: what was written, what was
already right, what drifted, what was warned about, and what nothing accounts for. The exit
status is 1 when there is drift and 0 otherwise, so `--check` is usable from a script without
parsing anything.

#chunk("main: the map arm", ````rust
Command::Map {
    file,
    typ,
    line,
    json,
    out,
} => {
    let out = out_dir(out, &[]);
    let maps = map::LpMap::read_all(&out);
````)

`map` has two directions, and they are different enough to be separate fragments. In reverse
it scans every run in every file, which is a linear search — acceptable because it runs when
a person asks, not in a loop.

#chunk("main: map, in reverse", ````rust
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
        if json {
            let places: Vec<serde_json::Value> = hits
                .iter()
                .map(|(file, line)| json!({"file": file, "line": line}))
                .collect();
            machine("map", json!({"chunk": chunk, "hits": places}))?;
            return Ok(0);
        }
        for (file, line) in &hits {
            println!("{file}:{line}");
        }
        if hits.is_empty() {
            eprintln!("note: nothing in the generated files came from chunk ⟪{chunk}⟫");
        }
        return Ok(0);
    }
````)

Forward, it resolves the file to one map (the search from the map chapter, including its
refusal to guess) and then asks that map for the run covering the line. The four flags arrive as four
options, and the surface has already refused every combination but two of them — this match is where a file
and a line become the pair the rest of the arm needs, and its fallback names the rule rather than trusting a
guarantee a compiler cannot see.

#chunk("main: map, forward", ````rust
    let (file, line) = match (file, line) {
        (Some(file), Some(line)) => (file, line),
        _ => {
            return Err(LpError::plain("lp map takes one direction").with_help(
                "use `lp map --file src/main.rs --line 42` for a generated line, or `lp map --typ <chunk>` the other way",
            ))
        }
    };
    let (dir, name, entry) = map::resolve_all(&maps, &file)?;
    let rel = map::join(dir, name);
    let Some((run, offset)) = entry.locate(line) else {
        return Err(LpError::plain(format!(
            "{rel}:{line}: no map knows this file"
        )));
    };
````)

#chunk("main: map, the answer", ````rust
    if json {
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
        return Ok(0);
    }
    println!("chunk ⟪{}⟫, line {offset} of it", run.chunk);
    println!("    find it with: rg '#chunk(\"{}\")'", run.chunk);
    Ok(0)
````)

#chunk("main: explain, a filter on stdin", ````rust
Command::Explain { out } => {
    let out = out_dir(out, &[]);
    let mut input = String::new();
    std::io::stdin()
        .read_to_string(&mut input)
        .map_err(|e| LpError::plain(e.to_string()))?;
    let mapped = explain::run(&out, &input)?;
    if mapped == 0 {
        eprintln!("note: no diagnostic line matched any map");
    }
    Ok(0)
}
````)

Reading standard input rather than taking a file means the command composes: anything that
prints diagnostics can be piped in, and the note about nothing matching goes to stderr so the
pipeline's stdout stays exactly what it was.

#chunk("main: list, one document", ````rust
Command::List { doc, json } => {
    list(std::slice::from_ref(&doc), json)?;
    Ok(0)
}
````)

#chunk("main: metadata, the stream itself", ````rust
Command::Metadata { docs, json } => {
    let typst = metadata::binary()?;
    let declarations = metadata::declarations(&typst, &docs)?;

    if json {
        machine("metadata", json!({ "declarations": declarations }))?;
        return Ok(0);
    }

    for declaration in declarations {
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
````)

#chunk("main: unaccounted, which needs a plan", ````rust
Command::Unaccounted { docs, out, delete } => {
    let out = out_dir(out, &docs);
    let plan = tangle::plan(&docs)?;
    status::run(&out, &tangle::produced(&plan), delete)
}
````)

== The one command with a view of its own

`list` is a debug view, and it is the one place in this file where the program looks at the
plan's contents rather than handing them to a module: it needs the set of names that are
referenced, which `plan` computes internally and does not expose. Widening `Plan` for a
debug command seemed the worse trade, so the three lines are repeated here — a wart, kept
deliberately, and this is where it is recorded.

#chunk("main: plan, and who is referenced", ````rust
let plan = tangle::plan(docs)?;
let set = tangle::ChunkSet::new(&plan.blocks);
let referenced: BTreeSet<String> = plan.blocks.iter().flat_map(tangle::refs_of).collect();
````)

#chunk("main: the same list, for a program", ````rust
if json {
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
    return machine(
        "list",
        json!({
            "documents": docs.iter().map(|doc| doc.display().to_string()).collect::<Vec<_>>(),
            "declarations": declarations,
            "outputs": set.roots(),
        }),
    );
}
````)

#chunk("main: one row per declaration", ````rust
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
````)

#chunk("main: the outputs at the end", ````rust
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
````)
