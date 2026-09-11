//! Tangling: expand chunks into whole files, write them, and record where every
//! output line came from.
//!
//! Which chunks exist is Typst's answer (`metadata.rs`); where each one was
//! written is a search (`locate.rs`). What is left here is our own, much smaller
//! part: `<<references>>`, indentation, writing files, and the line map.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};
use std::sync::Arc;

use crate::diag::LpError;
use crate::locate::{self, Placed};
use crate::map::{ChunkEntry, FileMap, LpMap, MAP_FILE, split};
use crate::metadata;
use crate::source::{self, FileText, check_output_path};

/// A chunk as the document produced it, plus the place we could find for it.
pub struct Block {
    /// A `file` declaration names the path it is tangled to; a `chunk` is a
    /// fragment that only exists where it is referenced.
    pub root: bool,
    pub name: String,
    pub lang: Option<String>,
    pub text: String,
    pub place: Placed,
}

impl Block {
    /// An error pointing at the `index`-th line of this chunk, when the source has
    /// one. A chunk the document built has no line of its own, and saying so beats
    /// pointing somewhere wrong.
    fn error(&self, index: usize, message: impl Into<String>, label: impl Into<String>) -> LpError {
        let message = message.into();
        match self.place.line_for(index) {
            Some((file, line)) => match file.line_range(line) {
                Some(range) => LpError::at(&file.named, range, message, label),
                None => LpError::plain(message),
            },
            None => LpError::plain(message).with_help(format!(
                "chunk <<{}>> was built by the document rather than written literally",
                self.name
            )),
        }
    }

    fn where_(&self) -> String {
        match self.place.line_for(0) {
            Some((file, line)) => format!("{}:{line}: ", file.path.display()),
            None => String::new(),
        }
    }
}

pub struct ChunkSet<'a> {
    chunks: BTreeMap<&'a str, Vec<&'a Block>>,
}

impl<'a> ChunkSet<'a> {
    /// One set over every chunk of the invocation, in the order the document
    /// produced them.
    pub fn new(blocks: &'a [Block]) -> Self {
        let mut chunks: BTreeMap<&str, Vec<&Block>> = BTreeMap::new();
        for block in blocks {
            chunks.entry(block.name.as_str()).or_default().push(block);
        }
        Self { chunks }
    }

    /// The declared files, in the order the document declared them.
    pub fn roots(&self) -> Vec<&'a str> {
        let mut roots: Vec<&str> = Vec::new();
        for blocks in self.chunks.values() {
            if let Some(block) = blocks.first()
                && block.root
                && !roots.contains(&block.name.as_str())
            {
                roots.push(block.name.as_str());
            }
        }
        roots
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
    /// `[output line, line in that source, index into the plan's sources]`. The
    /// last two are `None` when the document built the line rather than wrote it.
    pub lines: Vec<(usize, Option<usize>, Option<usize>)>,
    pub chunks: Vec<ChunkEntry>,
}

pub fn expand(set: &ChunkSet, root: &str, sources: &[Arc<FileText>]) -> Result<Tangled, LpError> {
    let mut out = Tangled {
        text: String::new(),
        lines: Vec::new(),
        chunks: Vec::new(),
    };
    let mut stack = Vec::new();
    expand_chunk(set, root, "", &mut stack, &mut out, sources)?;
    Ok(out)
}

fn expand_chunk(
    set: &ChunkSet,
    name: &str,
    indent: &str,
    stack: &mut Vec<String>,
    out: &mut Tangled,
    sources: &[Arc<FileText>],
) -> Result<(), LpError> {
    if let Some(start) = stack.iter().position(|entry| entry == name) {
        let mut chain: Vec<String> = stack[start..].to_vec();
        chain.push(name.to_string());
        let message = format!("cycle in chunks: {}", chain.join(" -> "));
        let block = set.get(name).and_then(|blocks| blocks.first()).copied();
        return Err(match block {
            Some(block) => block.error(0, message, "this chunk is part of the cycle"),
            None => LpError::plain(message),
        });
    }
    stack.push(name.to_string());

    for block in set.get(name).unwrap_or(&[]) {
        if block.text.trim().is_empty() {
            stack.pop();
            return Err(block
                .error(0, format!("chunk <<{name}>> is empty"), "empty chunk")
                .with_help("delete it, or give it a body"));
        }

        let span = match &block.place {
            Placed::Nowhere => None,
            _ => block.place.line_for(0).map(|(_, line)| {
                let last = line + block.text.lines().count().saturating_sub(1);
                (
                    line,
                    if matches!(block.place, Placed::Generated { .. }) {
                        line
                    } else {
                        last
                    },
                )
            }),
        };
        out.chunks.push(ChunkEntry {
            name: name.to_string(),
            typ_line: span.map(|(first, _)| first),
            end_line: span.map(|(_, last)| last),
        });

        for (index, line) in block.text.lines().enumerate() {
            let located = block.place.line_for(index).and_then(|(file, line)| {
                sources
                    .iter()
                    .position(|candidate| candidate.path == file.path)
                    .map(|position| (position, line))
            });

            match ref_target(line) {
                None => {
                    out.lines.push((
                        out.lines.len() + 1,
                        located.map(|(_, line)| line),
                        located.map(|(position, _)| position),
                    ));
                    out.text.push_str(indent);
                    out.text.push_str(line);
                    out.text.push('\n');
                }
                Some((target, local_indent)) => {
                    if set.get(target).is_none() {
                        return Err(block
                            .error(
                                index,
                                format!("chunk <<{target}>> is not defined"),
                                format!("referenced from <<{name}>>"),
                            )
                            .with_help(format!(
                                "known chunks: {}",
                                set.names().collect::<Vec<_>>().join(", ")
                            )));
                    }
                    let nested = format!("{indent}{local_indent}");
                    expand_chunk(set, target, &nested, stack, out, sources)?;
                }
            }
        }
    }

    stack.pop();
    Ok(())
}

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
    /// Files under the output directory that neither a chunk nor a declaration
    /// accounts for. Non-empty means the pass failed.
    pub unaccounted: Vec<crate::status::Unaccounted>,
    pub warnings: Vec<String>,
}

/// What the documents produce, without writing anything.
pub struct Plan {
    pub maps: BTreeMap<PathBuf, LpMap>,
    pub texts: BTreeMap<String, String>,
    pub warnings: Vec<String>,
    pub blocks: Vec<Block>,
}

pub fn plan(docs: &[PathBuf]) -> Result<Plan, LpError> {
    let typst = metadata::binary()?;
    let cwd = std::env::current_dir().map_err(|err| LpError::plain(err.to_string()))?;

    let sources = source::sources(docs)?;

    let declarations = metadata::declarations(&typst, docs, &cwd)?;
    let places = locate::places(&sources, &declarations);
    let blocks: Vec<Block> = declarations
        .into_iter()
        .zip(places)
        .map(|(declaration, place)| Block {
            root: declaration.is_file(),
            name: declaration.name,
            lang: declaration.lang,
            text: declaration.text,
            place,
        })
        .collect();

    let set = ChunkSet::new(&blocks);
    if set.roots().is_empty() {
        let listed = docs
            .iter()
            .map(|doc| doc.display().to_string())
            .collect::<Vec<_>>()
            .join(", ");
        return Err(
            LpError::plain(format!("no root chunks in {listed}")).with_help(
                "a root chunk is a label that names a file, e.g. ```rust ... ``` <src/main.rs>",
            ),
        );
    }

    let mut warnings = Vec::new();
    let referenced: BTreeSet<String> = blocks.iter().flat_map(refs_of).collect();
    let file_names: BTreeSet<&str> = blocks
        .iter()
        .filter(|block| block.root)
        .map(|block| block.name.as_str())
        .collect();
    for name in set.names() {
        if !file_names.contains(name) && !referenced.contains(name) {
            let block = set.get(name).and_then(|blocks| blocks.first());
            let where_ = block.map_or_else(String::new, |block| block.where_());
            warnings.push(format!("{where_}chunk <<{name}>> is never referenced"));
        }
    }

    let mut maps: BTreeMap<PathBuf, LpMap> = BTreeMap::new();
    let mut texts: BTreeMap<String, String> = BTreeMap::new();
    let mut produced: BTreeSet<String> = BTreeSet::new();
    for root in set.roots() {
        check_output_path(root)?;
        let lang = set
            .get(root)
            .and_then(|blocks| blocks.first())
            .and_then(|block| block.lang.clone());
        let tangled = expand(&set, root, &sources)?;

        if !produced.insert(root.to_string()) {
            return Err(LpError::plain(format!("output {root} is produced twice")));
        }

        // An output names only the source files its own lines came from, and each
        // line entry indexes into that shorter list.
        let used: BTreeSet<usize> = tangled.lines.iter().filter_map(|entry| entry.2).collect();
        let named: Vec<String> = used
            .iter()
            .map(|index| sources[*index].path.display().to_string())
            .collect();
        let remapped: BTreeMap<usize, usize> = used
            .iter()
            .enumerate()
            .map(|(position, index)| (*index, position))
            .collect();
        let lines = tangled
            .lines
            .iter()
            .map(|entry| (entry.0, entry.1, entry.2.map(|index| remapped[&index])))
            .collect();

        let entry = FileMap {
            sources: named,
            lang,
            lines,
            chunks: tangled.chunks,
        };
        let (dir, name) = split(root);
        maps.entry(PathBuf::from(dir))
            .or_default()
            .files
            .insert(name.to_string(), entry);
        texts.insert(root.to_string(), tangled.text);
    }

    Ok(Plan {
        maps,
        texts,
        warnings,
        blocks,
    })
}

/// What the documents produce, per directory: what `status.rs` counts against.
pub fn produced(plan: &Plan) -> BTreeMap<String, BTreeSet<String>> {
    plan.maps
        .iter()
        .map(|(dir, map)| {
            (
                dir.to_string_lossy().replace('\\', "/"),
                map.files.keys().cloned().collect(),
            )
        })
        .collect()
}

pub fn run(docs: &[PathBuf], out: &Path, check: bool) -> Result<Outcome, LpError> {
    let plan = plan(docs)?;
    let mut outcome = Outcome {
        warnings: plan.warnings.clone(),
        ..Outcome::default()
    };

    // Everything under the output directory must be accounted for: produced by a
    // chunk, or declared in a `.lpignore`. Anything else is an error rather than
    // something to quietly remove — deleting a root chunk strands a file, and the
    // user decides whether to declare it or delete it.
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

    for (root, text) in &plan.texts {
        let (dir, name) = split(root);
        let entry = &plan.maps[Path::new(dir)].files[name];
        let dest = out.join(root);
        let existing = std::fs::read_to_string(&dest).ok();
        let output = Output {
            root: root.clone(),
            lines: entry.lines.len(),
            lang: entry.lang.clone(),
        };

        if existing.as_deref() == Some(text.as_str()) {
            outcome.unchanged.push(output);
        } else if check {
            outcome.stale.push(drift_report(
                entry.sources.first().map(String::as_str).unwrap_or("-"),
                root,
                existing.as_deref(),
                &entry.lines,
                text,
            ));
        } else {
            if let Some(parent) = dest.parent() {
                std::fs::create_dir_all(parent).map_err(|err| LpError::io(parent, err))?;
            }
            std::fs::write(&dest, text).map_err(|err| LpError::io(&dest, err))?;
            outcome.changed.push(output);
        }
    }

    // A map tracks the *document*, so it can be stale even when no output byte
    // moved (a line of prose shifts every mapping); `write_if_changed` compares
    // content rather than the output files'. Maps for directories that stopped
    // producing anything are removed with the directories themselves: the map
    // travels with the files it explains.
    if !check {
        let mut live: BTreeSet<String> = BTreeSet::new();
        for (dir, mut map) in plan.maps {
            if map.is_empty() {
                continue;
            }
            let dir = dir.to_string_lossy().replace('\\', "/");
            map.set_docs(
                map.files
                    .values()
                    .flat_map(|file| file.sources.iter().cloned())
                    .collect::<Vec<_>>(),
            );
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
    }
    Ok(outcome)
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
        .find(|&index| old_lines.get(index) != new_lines.get(index))
        .map(|index| index + 1)
}

fn drift_report(
    typ: &str,
    root: &str,
    existing: Option<&str>,
    lines: &[(usize, Option<usize>, Option<usize>)],
    text: &str,
) -> String {
    match first_difference(existing, text) {
        Some(line) => {
            let origin = lines
                .iter()
                .rev()
                .find(|entry| entry.0 <= line)
                .and_then(|entry| entry.1);
            match origin {
                Some(typ_line) => format!("STALE  {root} (line {line} <- {typ}:{typ_line})"),
                None => format!("STALE  {root} (line {line}, built by the document)"),
            }
        }
        None => format!("STALE  {root} (file missing)"),
    }
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
