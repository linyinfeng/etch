#import "@local/lp:0.1.0": chunk

= Writing the pass

`run` is the three steps in order, and what makes them worth separating is that none of them is allowed to
decide something another one has not: the plan is computed first, the writing puts down only what the plan
says changed, and the result is judged from the plan rather than from a second look at the disk.

#chunk("tangle: plan, then an empty outcome", ````rust
let plan = plan(docs)?;
let documented = book_relative(docs);
let book = plan.book.clone();
let mut outcome = Outcome {
    warnings: plan.warnings.clone(),
    ..Outcome::default()
};
````)

Then the loop that compares each planned file with what is on disk: identical bytes are left
alone — mtime included, so build tools do not rebuild — and a difference is either written,
or, in check mode, reported as drift.

#chunk("tangle: write what changed", ````rust
let (dir, name) = split(root);
let entry = &plan.maps[Path::new(dir)].files[name];
let dest = out.join(root);
let existing = std::fs::read_to_string(&dest).ok();
let output = Output {
    root: root.clone(),
    lines: text.lines().count(),
    lang: entry.lang.clone(),
};
````)

#chunk("tangle: or say what drifted", ````rust
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
````)

Then the ownership check, after the write, for the reason recorded in D20: a `.lpignore` can
itself be something the document produces, so a fresh tree has no control file until this
pass writes one, and checking first would refuse to bootstrap.

#chunk("tangle: everything must be accounted for", ````rust
if let Some(book) = &plan.book {
    let carried = crate::book::place(out, &plan.book_copies, check)?;
    if carried > 0 {
        let plural = if carried == 1 { "" } else { "s" };
        println!("carried {carried} book file{plural}");
    }
    let removed = crate::book::sweep(out, &book.directory, &plan.book_copies, check)?;
    if removed > 0 {
        let plural = if removed == 1 { "" } else { "s" };
        println!("removed {removed} stale book file{plural}");
    }
}
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
````)

And last the maps: written only when they changed, and removed when the directory they
describe stopped producing anything, along with the directories themselves. A map is not a
log of what once existed; it describes what is there now.

#chunk("tangle: the maps, and the ones that stopped applying", ````rust
let mut live: BTreeSet<String> = BTreeSet::new();
for (dir, mut map) in plan.maps {
    if map.is_empty() {
        continue;
    }
    let dir = dir.to_string_lossy().replace('\\', "/");
    if dir.is_empty() {
        map.set_docs(documented.clone());
        map.book = book.clone();
    }
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
````)

== Saying what drifted

The drift report is deliberately one line per file: where the first difference is, and which
chunk produced the line on the *document's* side. Anything more is a diff, and a diff is not
what the reader needs — the reader needs the name of the thing to edit.

#chunk("tangle: where two texts first differ", ````rust
fn first_difference(old: Option<&str>, new: &str) -> Option<usize> {
    let old = old?;
    let old_lines: Vec<&str> = old.lines().collect();
    let new_lines: Vec<&str> = new.lines().collect();
    (0..old_lines.len().max(new_lines.len()))
        .find(|&index| old_lines.get(index) != new_lines.get(index))
        .map(|index| index + 1)
}
````)

#chunk("tangle: the drift report", ````rust
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
````)

== The two predicates, pinned

Two unit tests, because these are the two predicates the whole pass rests on: what counts as a
reference, and what the escape does. Both are pure functions of a line, which is why they can be
pinned here rather than by tangling a document.

#chunk("tangle: the two shapes, pinned", ````rust
#[cfg(test)]
mod tests {
    use super::{escaped_ref, ref_target};

    #[test]
    fn only_a_whole_line_reference_counts() {
        assert_eq!(ref_target("<<body>>"), Some(("body", "")));
        assert_eq!(ref_target("    <<body>>  "), Some(("body", "    ")));
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
