//! Tangling: expand chunks into whole files, write them, and record where every
//! output line came from.
//!
//! Which chunks exist is Typst's answer (`metadata.rs`); where each one was
//! written is a search (`locate.rs`). What is left here is our own, much smaller
//! part: `<<references>>`, indentation, writing files, and the line map.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use crate::diag::LpError;
use crate::map::{FileMap, LpMap, MAP_FILE, Run, split};
use crate::metadata;

/// A chunk as the document declared it.
pub struct Block {
    /// A `file` declaration names the path it is tangled to; a `chunk` is a
    /// fragment that only exists where it is referenced.
    pub root: bool,
    pub name: String,
    pub lang: Option<String>,
    pub text: String,
}

impl Block {
    /// An error about the `index`-th line of this chunk. It quotes the line: with
    /// no source positions to point at, the quote is what tells the reader where
    /// to look (ADR D14).
    fn error(&self, index: usize, message: impl Into<String>) -> LpError {
        let line = self.text.lines().nth(index).unwrap_or("");
        LpError::plain(format!("{}: {line}", message.into())).with_help(format!(
            "in chunk ⟪{}⟫, line {} of it",
            self.name,
            index + 1
        ))
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

/// Reject declared paths that would write outside the output directory.
pub fn check_output_path(name: &str) -> Result<(), LpError> {
    let unsafe_name = name.is_empty()
        || name.starts_with('/')
        || name.contains('\\')
        || Path::new(name).components().any(|component| {
            matches!(
                component,
                std::path::Component::ParentDir
                    | std::path::Component::RootDir
                    | std::path::Component::Prefix(_)
            )
        });

    if unsafe_name {
        return Err(LpError::plain(format!("unsafe chunk name {name:?}"))
            .with_help("a file declaration must be a relative path inside --out, without `..`"));
    }
    Ok(())
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
    /// Which chunk produced which consecutive output lines.
    pub runs: Vec<Run>,
    /// Lines written so far, so a run can be extended without counting the text.
    lines: usize,
}

impl Tangled {
    fn push(&mut self, chunk: &str, indent: &str, line: &str) {
        self.text.push_str(indent);
        self.text.push_str(line);
        self.text.push('\n');
        self.lines += 1;
        match self.runs.last_mut() {
            Some(run) if run.chunk == chunk && run.last + 1 == self.lines => run.last = self.lines,
            _ => self.runs.push(Run {
                chunk: chunk.to_string(),
                first: self.lines,
                last: self.lines,
            }),
        }
    }
}

pub fn expand(set: &ChunkSet, root: &str) -> Result<Tangled, LpError> {
    let mut out = Tangled {
        text: String::new(),
        runs: Vec::new(),
        lines: 0,
    };
    let mut stack = Vec::new();
    expand_chunk(set, root, "", &mut stack, &mut out)?;
    Ok(out)
}

fn expand_chunk(
    set: &ChunkSet,
    name: &str,
    indent: &str,
    stack: &mut Vec<String>,
    out: &mut Tangled,
) -> Result<(), LpError> {
    if let Some(start) = stack.iter().position(|entry| entry == name) {
        let mut chain: Vec<String> = stack[start..].to_vec();
        chain.push(name.to_string());
        let message = format!("cycle in chunks: {}", chain.join(" -> "));
        let block = set.get(name).and_then(|blocks| blocks.first()).copied();
        return Err(match block {
            Some(block) => block.error(0, message),
            None => LpError::plain(message),
        });
    }
    stack.push(name.to_string());

    for block in set.get(name).unwrap_or(&[]) {
        if block.text.trim().is_empty() {
            stack.pop();
            return Err(LpError::plain(format!("chunk ⟪{name}⟫ is empty"))
                .with_help("delete the declaration, or give it a code block with a body"));
        }

        for (index, line) in block.text.lines().enumerate() {
            match ref_target(line) {
                None => out.push(name, indent, line),
                Some((target, local_indent)) => {
                    if set.get(target).is_none() {
                        return Err(block
                            .error(index, format!("chunk ⟪{target}⟫ is not defined"))
                            .with_help(format!(
                                "referenced from ⟪{name}⟫; known chunks: {}",
                                set.names().collect::<Vec<_>>().join(", ")
                            )));
                    }
                    let nested = format!("{indent}{local_indent}");
                    expand_chunk(set, target, &nested, stack, out)?;
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

    let blocks: Vec<Block> = metadata::declarations(&typst, docs, &cwd)?
        .into_iter()
        .map(|declaration| Block {
            root: declaration.is_file(),
            name: declaration.name,
            lang: declaration.lang,
            text: declaration.text,
        })
        .collect();

    let set = ChunkSet::new(&blocks);
    if set.roots().is_empty() {
        let listed = docs
            .iter()
            .map(|doc| doc.display().to_string())
            .collect::<Vec<_>>()
            .join(", ");
        return Err(LpError::plain(format!("no file declarations in {listed}"))
            .with_help("declare one: `#file(\"src/main.rs\", ```…```)`"));
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
            warnings.push(format!("chunk ⟪{name}⟫ is never referenced"));
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
        let tangled = expand(&set, root)?;

        if !produced.insert(root.to_string()) {
            return Err(LpError::plain(format!("output {root} is produced twice")));
        }

        let entry = FileMap {
            lang,
            runs: tangled.runs,
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
    let documented = docs
        .iter()
        .map(|doc| doc.display().to_string())
        .collect::<Vec<_>>();
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
            lines: text.lines().count(),
            lang: entry.lang.clone(),
        };

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
            map.set_docs(documented.clone());
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
