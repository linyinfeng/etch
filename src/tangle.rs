//! Tangling: expand chunks into whole files, write them, and record where every
//! output line came from.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use crate::diag::LpError;
use crate::map::{ChunkEntry, FileMap, LpMap, MAP_FILE, split};
use crate::parse::{Block, Doc, check_output_path, is_root};
use crate::sweep;

pub struct ChunkSet<'a> {
    chunks: BTreeMap<&'a str, Vec<&'a Block>>,
}

impl<'a> ChunkSet<'a> {
    pub fn new(doc: &'a Doc) -> Self {
        let mut chunks: BTreeMap<&str, Vec<&Block>> = BTreeMap::new();
        for block in &doc.blocks {
            chunks.entry(block.name.as_str()).or_default().push(block);
        }
        Self { chunks }
    }

    /// Chunks whose name looks like a file become output files.
    pub fn roots(&self) -> Vec<&'a str> {
        self.chunks
            .keys()
            .copied()
            .filter(|name| is_root(name))
            .collect()
    }

    pub fn names(&self) -> impl Iterator<Item = &'a str> {
        self.chunks.keys().copied()
    }

    pub fn get(&self, name: &str) -> Option<&[&'a Block]> {
        self.chunks.get(name).map(Vec::as_slice)
    }
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

pub struct Tangled {
    /// File contents, always ending in a newline.
    pub text: String,
    /// `[output line, .typ line]`, in output order.
    pub lines: Vec<[usize; 2]>,
    pub chunks: Vec<ChunkEntry>,
}

pub fn expand(doc: &Doc, set: &ChunkSet, root: &str) -> Result<Tangled, LpError> {
    let mut out = Tangled {
        text: String::new(),
        lines: Vec::new(),
        chunks: Vec::new(),
    };
    let mut stack = Vec::new();
    expand_chunk(doc, set, root, "", &mut stack, &mut out)?;
    Ok(out)
}

fn expand_chunk(
    doc: &Doc,
    set: &ChunkSet,
    name: &str,
    indent: &str,
    stack: &mut Vec<String>,
    out: &mut Tangled,
) -> Result<(), LpError> {
    if let Some(start) = stack.iter().position(|n| n == name) {
        let mut chain: Vec<String> = stack[start..].to_vec();
        chain.push(name.to_string());
        let message = format!("cycle in chunks: {}", chain.join(" -> "));
        let block = set.get(name).and_then(|blocks| blocks.first()).copied();
        return Err(match block {
            Some(block) => LpError::at(
                &doc.src,
                block.span.clone(),
                message,
                "this chunk is part of the cycle",
            ),
            None => LpError::plain(message),
        });
    }
    stack.push(name.to_string());

    for block in set.get(name).unwrap_or(&[]) {
        if block.text.is_empty() {
            stack.pop();
            return Err(LpError::at(
                &doc.src,
                block.span.clone(),
                format!("chunk <<{name}>> is empty"),
                "empty chunk",
            )
            .with_help("delete it, or give it a body"));
        }

        out.chunks.push(ChunkEntry {
            name: name.to_string(),
            typ_line: block.fence_line,
            end_line: block.fence_line + block.text.lines().count() + 1,
        });

        for (i, line) in block.text.lines().enumerate() {
            let typ_line = block.fence_line + 1 + i;
            match ref_target(line) {
                None => {
                    out.lines.push([out.lines.len() + 1, typ_line]);
                    out.text.push_str(indent);
                    out.text.push_str(line);
                    out.text.push('\n');
                }
                Some((target, local_indent)) => {
                    if set.get(target).is_none() {
                        let range = doc
                            .line_range(typ_line)
                            .unwrap_or_else(|| block.span.clone());
                        return Err(LpError::at(
                            &doc.src,
                            range,
                            format!("chunk <<{target}>> is not defined"),
                            format!("referenced from <<{name}>>"),
                        )
                        .with_help(format!(
                            "known chunks: {}",
                            set.names().collect::<Vec<_>>().join(", ")
                        )));
                    }
                    let nested = format!("{indent}{local_indent}");
                    expand_chunk(doc, set, target, &nested, stack, out)?;
                }
            }
        }
    }

    stack.pop();
    Ok(())
}

/// One output file produced by a pass. Printing is the caller's job: the watch
/// loop wants the same facts without the per-file chatter.
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
    /// Stale files a sweep removed because a declared directory produced them no
    /// more.
    pub pruned: Vec<String>,
    /// Directories that declared ownership with a `.lpignore`.
    pub managed: Vec<String>,
    /// `.lpignore` files the pass walked past, relative to the output directory.
    pub declared: Vec<String>,
    pub warnings: Vec<String>,
}

/// Tangle every document into `out`; with `check`, write nothing and only report
/// drift against what is already there.
pub fn run(docs: &[Doc], out: &Path, check: bool) -> Result<Outcome, LpError> {
    // The map is a line map: what this pass produced, nothing more. Ownership of
    // files that no chunk produces any more is a directory question, answered by
    // `.lpignore` (see `sweep.rs`), not by remembering the past here.
    // One map per output directory, filled as roots are expanded; `produced`
    // stays the flat list of paths for the sweep.
    let mut maps: BTreeMap<PathBuf, LpMap> = BTreeMap::new();
    let mut produced: BTreeSet<String> = BTreeSet::new();
    let mut outcome = Outcome::default();

    for doc in docs {
        // Never tangle a half-written document: an unclosed label turns a chunk
        // into plain text, so the generated file would silently lose code.
        if let Some(error) = doc.errors.first() {
            let message = format!("{}: syntax error: {}", doc.path.display(), error.message);
            let err = match error.range.clone() {
                Some(range) => LpError::at(&doc.src, range, message, "the document does not parse"),
                None => LpError::plain(message),
            };
            return Err(err.with_help(
                "tangling a half-written document can silently drop chunks; run `typst compile` for the full diagnostic",
            ));
        }

        let set = ChunkSet::new(doc);
        let roots = set.roots();
        if roots.is_empty() {
            return Err(
                LpError::plain(format!("{}: no root chunks", doc.path.display())).with_help(
                    "a root chunk is a label that names a file, e.g. ```rust ... ``` <src/main.rs>",
                ),
            );
        }

        let referenced: BTreeSet<String> = doc.blocks.iter().flat_map(refs_of).collect();
        for name in set.names() {
            if !is_root(name) && !referenced.contains(name) {
                let line = set
                    .get(name)
                    .and_then(|b| b.first())
                    .map_or(0, |b| b.fence_line);
                outcome.warnings.push(format!(
                    "{}:{line}: chunk <<{name}>> is never referenced",
                    doc.path.display()
                ));
            }
        }

        for root in roots {
            check_output_path(root)?;
            let lang = doc
                .blocks
                .iter()
                .find(|b| b.name == root)
                .and_then(|b| b.lang.clone());
            let tangled = expand(doc, &set, root)?;
            let dest = out.join(root);
            let existing = std::fs::read_to_string(&dest).ok();

            let output = Output {
                root: root.to_string(),
                lines: tangled.lines.len(),
                lang: lang.clone(),
            };

            if existing.as_deref() == Some(tangled.text.as_str()) {
                outcome.unchanged.push(output);
            } else if check {
                outcome
                    .stale
                    .push(drift_report(doc, root, existing.as_deref(), &tangled));
            } else {
                if let Some(parent) = dest.parent() {
                    std::fs::create_dir_all(parent).map_err(|e| LpError::io(parent, e))?;
                }
                std::fs::write(&dest, &tangled.text).map_err(|e| LpError::io(&dest, e))?;
                outcome.changed.push(output);
            }

            let entry = FileMap {
                typ: doc.path.display().to_string(),
                lang,
                lines: tangled.lines,
                chunks: tangled.chunks,
            };
            if !produced.insert(root.to_string()) {
                return Err(LpError::plain(format!("output {root} is produced twice")));
            }
            let (dir, name) = split(root);
            maps.entry(PathBuf::from(dir))
                .or_default()
                .files
                .insert(name.to_string(), entry);
        }
    }

    // Deleting a root chunk leaves a file behind. Removing it is the job of a
    // directory that declared itself ours, so a sweep runs wherever a `.lpignore`
    // says so — and nowhere else.
    let sweep = sweep::run(out, &produced, !check)?;
    outcome.managed = sweep.roots.clone();
    outcome.declared = sweep.declared.clone();
    for rel in sweep.removed {
        if check {
            outcome
                .stale
                .push(format!("ORPHAN {rel} (would be removed)"));
        } else {
            outcome.pruned.push(rel);
        }
    }

    // A map tracks the *document*, so it can be stale even when no output byte
    // moved (a line of prose shifts every mapping); `write_if_changed` compares
    // content rather than the output files'. Maps for directories that stopped
    // producing anything are removed with the directories themselves: the map
    // travels with the files it explains.
    if !check {
        for (dir, map) in maps.iter_mut() {
            if map.is_empty() {
                continue;
            }
            map.set_docs(
                map.files
                    .values()
                    .map(|file| file.typ.clone())
                    .collect::<Vec<_>>(),
            );
            map.write_if_changed(&out.join(dir))?;
        }
        for (dir, _) in LpMap::read_all(out) {
            if maps.get(Path::new(&dir)).is_some_and(|map| !map.is_empty()) {
                continue;
            }
            let stale = out.join(&dir).join(MAP_FILE);
            if std::fs::remove_file(&stale).is_ok() {
                sweep::prune_empty_dirs(stale.parent().unwrap_or(out), out);
            }
        }
    }
    Ok(outcome)
}

fn drift_report(doc: &Doc, root: &str, existing: Option<&str>, tangled: &Tangled) -> String {
    match first_difference(existing, &tangled.text) {
        Some(line) => {
            let origin = tangled
                .lines
                .iter()
                .rev()
                .find(|e| e[0] <= line)
                .map(|e| e[1]);
            match origin {
                Some(typ_line) => format!(
                    "STALE  {root} (line {line} <- {}:{typ_line})",
                    doc.path.display()
                ),
                None => format!("STALE  {root} (line {line})"),
            }
        }
        None => format!("STALE  {root} (file missing)"),
    }
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
        .find(|&i| old_lines.get(i) != new_lines.get(i))
        .map(|i| i + 1)
}

#[cfg(test)]
mod tests {
    use super::ref_target;

    #[test]
    fn only_a_whole_line_reference_counts() {
        assert_eq!(ref_target("<<body>>"), Some(("body", "")));
        assert_eq!(ref_target("    <<body>>  "), Some(("body", "    ")));
        // Not references: they must survive tangling as literal text.
        assert_eq!(ref_target("std::cout << x << std::endl;"), None);
        assert_eq!(ref_target("<<a>><<b>>"), None);
        assert_eq!(ref_target("auto y = <<x>>;"), None);
    }
}
