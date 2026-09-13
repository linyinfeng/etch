#import "../../package/lib.typ": chunk

= Writing the pass

`run` is the three steps in order, and what makes them worth separating is that none of them is allowed to
decide something another one has not: the plan is computed first, the writing puts down only what the plan
says changed, and the result is judged from the plan rather than from a second look at the disk.

#chunk("tangle: plan, then an empty outcome", ````rust
let plan = plan(docs)?;
let documented = book_relative(docs);
let book = plan.book.clone();
let mut outcome = Outcome {
    unreferenced: plan.unreferenced.clone(),
    wordless: plan.wordless.clone(),
    ..Outcome::default()
};
````)

Then the loop that compares each planned file with what is on disk: identical bytes are left
alone — mtime included, so build tools do not rebuild — and a difference is either written,
or, in check mode, reported as drift.

#chunk("tangle: write what changed", ````rust
let (output, verdict) = look(&plan, root, text, out)?;
let dest = out.join(root);
````)

#chunk("tangle: or say what drifted", ````rust
match verdict {
    Disk::Same => outcome.unchanged.push(output),
    Disk::Absent if check => outcome.missing.push(root.clone()),
    Disk::Differs { line, chunk } if check => outcome.drifted.push(Drift {
        root: root.clone(),
        line,
        chunk,
    }),
    _ => {
        disk::write(&dest, text)?;
        outcome.changed.push(output);
    }
}
````)

== Planning is the same look, twice

The two commands ask the same question of the same plan — what is on disk beside what the document
says — and they answer it with the same three lines. What separates them is what they do with the
answer: a pass writes, a plan records, and neither of them decides anything the comparison has not
already said. A second comparison would be a second answer to the same question.

Then the ownership check, before anything the document says is written, for the reason recorded in D20 and the
consequence of it. The reason: a `.lpignore` can itself be something the document produces, so a fresh tree has
no control file until this pass writes one, and a check that ran before *that* would refuse to bootstrap. The
consequence: the control files are the one thing written first, and only when the pass is not a check. Once
they are there, the check runs against the disk as this pass would leave it, and one part of the tree is left
out of it: the book directory belongs to the pass, so whatever is under it is the sweep's to remove or keep
rather than a stray to report — and a file that was never a copy at all is still removed by that same sweep,
which is what makes a stale copy a thing a check can name. Everything else under the output is judged before a
byte of the document's content is written.

#chunk("tangle: the control files a check has to see", ````rust
if !check {
    for (root, text) in &plan.texts {
        if root.rsplit('/').next() != Some(crate::status::IGNORE_FILE) {
            continue;
        }
        let dest = out.join(root);
        if disk::read_ok(&dest)?.as_deref() != Some(text.as_str()) {
            disk::write(&dest, text)?;
        }
    }
}
````)

#chunk("tangle: everything must be accounted for", ````rust
outcome.unaccounted = crate::status::unaccounted(out, &produced(&plan))?;
if let Some(book) = &plan.book {
    let below = format!("{}/", book.directory);
    outcome
        .unaccounted
        .retain(|group| group.dir != book.directory && !group.dir.starts_with(&below));
}
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

#chunk("tangle: carrying the book, once nothing is unaccounted for", ````rust
if let Some(book) = &plan.book {
    outcome.carried = crate::book::place(out, &plan.book_copies, check)?;
    outcome.removed = crate::book::sweep(out, &book.directory, &plan.book_copies, check)?;
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
    if disk::remove_file(&stale).is_ok() {
        crate::status::prune_empty_dirs(stale.parent().unwrap_or(out), out);
    }
}
````)

== Saying what drifted

The drift report is deliberately one line per file: where the first difference is, and which
chunk produced the line on the *document's* side. Anything more is a diff, and a diff is not
what the reader needs — the reader needs the name of the thing to edit.

#chunk("tangle: where two texts first differ", ````rust
fn first_difference(old: &str, new: &str) -> Option<usize> {
    let old_lines: Vec<&str> = old.lines().collect();
    let new_lines: Vec<&str> = new.lines().collect();
    (0..old_lines.len().max(new_lines.len()))
        .find(|&index| old_lines.get(index) != new_lines.get(index))
        .map(|index| index + 1)
}
````)

#chunk("tangle: what the disk says", ````rust
enum Disk {
    Same,
    Absent,
    Differs {
        line: Option<usize>,
        chunk: Option<String>,
    },
}

fn look(plan: &Plan, root: &str, text: &str, out: &Path) -> Result<(Output, Disk), LpError> {
    let (dir, name) = split(root);
    let entry = &plan.maps[Path::new(dir)].files[name];
    let output = Output {
        root: root.to_string(),
        lines: text.lines().count(),
        lang: entry.lang.clone(),
    };
    let Some(on_disk) = disk::read_ok(&out.join(root))? else {
        return Ok((output, Disk::Absent));
    };
    if on_disk == text {
        return Ok((output, Disk::Same));
    }
    let line = first_difference(&on_disk, text);
    let chunk = line
        .and_then(|line| entry.runs.iter().rev().find(|run| run.first <= line))
        .map(|run| run.chunk.clone());
    Ok((output, Disk::Differs { line, chunk }))
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
