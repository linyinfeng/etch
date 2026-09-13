use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};

use serde::Serialize;

use crate::diag::EtchError;
use crate::disk;
use crate::map::{Book, EtchMap, FileMap, MAP_FILE, Run, split};
use crate::metadata;

pub struct Block {
    pub root: bool,
    pub name: String,
    pub lang: Option<String>,
    pub text: String,
}

impl Block {
    fn error(&self, index: usize, message: impl Into<String>) -> EtchError {
        let line = self.text.lines().nth(index).unwrap_or("");
        EtchError::plain(format!("{}: {line}", message.into())).with_help(format!(
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
    pub fn new(blocks: &'a [Block]) -> Self {
        let mut chunks: BTreeMap<&str, Vec<&Block>> = BTreeMap::new();
        for block in blocks {
            chunks.entry(block.name.as_str()).or_default().push(block);
        }
        Self { chunks }
    }

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

pub fn check_output_path(name: &str) -> Result<(), EtchError> {
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
        return Err(EtchError::plain(format!("unsafe chunk name {name:?}"))
            .with_help("a file declaration must be a relative path inside --out, without `..`"));
    }
    Ok(())
}

fn ref_target(line: &str) -> Option<(&str, &str)> {
    let trimmed = line.trim();
    let inner = trimmed.strip_prefix("<<")?.strip_suffix(">>")?;
    if inner.is_empty() || inner.contains('<') || inner.contains('>') {
        return None;
    }
    Some((inner, &line[..line.len() - line.trim_start().len()]))
}

fn escaped_ref(line: &str) -> Option<String> {
    let indent = &line[..line.len() - line.trim_start().len()];
    let rest = line.trim().strip_prefix('@')?;
    let inner = rest.strip_prefix("<<")?.strip_suffix(">>")?;
    if inner.is_empty() || inner.contains('<') || inner.contains('>') {
        return None;
    }
    Some(format!("{indent}<<{inner}>>"))
}

pub struct Tangled {
    pub text: String,
    pub runs: Vec<Run>,
    lines: usize,
}

impl Tangled {
    fn push(&mut self, chunk: &str, indent: &str, line: &str) {
        if !line.trim().is_empty() {
            self.text.push_str(indent);
            self.text.push_str(line);
        }
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

pub fn expand(set: &ChunkSet, root: &str) -> Result<Tangled, EtchError> {
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
) -> Result<(), EtchError> {
    if let Some(start) = stack.iter().position(|entry| entry == name) {
        let mut chain: Vec<String> = stack[start..].to_vec();
        chain.push(name.to_string());
        let message = format!("cycle in chunks: {}", chain.join(" -> "));
        let block = set.get(name).and_then(|blocks| blocks.first()).copied();
        return Err(match block {
            Some(block) => block.error(0, message),
            None => EtchError::plain(message),
        });
    }
    stack.push(name.to_string());

    for block in set.get(name).unwrap_or(&[]) {
        if block.text.trim().is_empty() {
            stack.pop();
            return Err(EtchError::plain(format!("chunk ⟪{name}⟫ is empty"))
                .with_help("delete the declaration, or give it a code block with a body"));
        }

        for (index, line) in block.text.lines().enumerate() {
            if let Some(literal) = escaped_ref(line) {
                out.push(name, indent, &literal);
                continue;
            }
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

#[derive(Debug, Serialize)]
pub struct Output {
    pub root: String,
    pub lines: usize,
    pub lang: Option<String>,
}

#[derive(Debug, Default)]
pub struct Outcome {
    pub changed: Vec<Output>,
    pub unchanged: Vec<Output>,
    pub drifted: Vec<Drift>,
    pub missing: Vec<String>,
    pub unaccounted: Vec<crate::status::Unaccounted>,
    pub unreferenced: BTreeSet<String>,
    pub wordless: BTreeSet<String>,
    pub carried: usize,
    pub removed: usize,
}

#[derive(Debug, Serialize)]
pub struct Drift {
    pub root: String,
    pub line: Option<usize>,
    pub chunk: Option<String>,
}

pub struct Plan {
    pub maps: BTreeMap<PathBuf, EtchMap>,
    pub texts: BTreeMap<String, String>,
    pub referenced: BTreeSet<String>,
    pub unreferenced: BTreeSet<String>,
    pub wordless: BTreeSet<String>,
    pub blocks: Vec<Block>,
    pub book: Option<Book>,
    pub book_copies: Vec<crate::book::Copy>,
}

fn settings(declaration: &metadata::Decl) -> Result<Book, EtchError> {
    let value = declaration
        .options
        .clone()
        .unwrap_or(serde_json::Value::Null);
    let table = value
        .as_object()
        .ok_or_else(|| EtchError::plain("tangle-options was given something that is not a dict"))?;
    for key in table.keys() {
        if key != "book-directory" && key != "extra-book-files" {
            return Err(EtchError::plain(format!("unknown tangle option {key:?}"))
                .with_help("known options: `book-directory`, `extra-book-files`"));
        }
    }
    let directory = table
        .get("book-directory")
        .and_then(|value| value.as_str())
        .ok_or_else(|| {
            EtchError::plain("tangle-options needs a `book-directory`")
                .with_help("a string: the directory inside the output that the book is copied into")
        })?
        .to_string();
    let mut files = Vec::new();
    if let Some(value) = table.get("extra-book-files") {
        let list = value
            .as_array()
            .ok_or_else(|| EtchError::plain("`extra-book-files` is a list of file names"))?;
        for entry in list {
            let name = entry
                .as_str()
                .ok_or_else(|| EtchError::plain("`extra-book-files` is a list of file names"))?;
            if name.starts_with('/') || name.split('/').any(|part| part == "..") {
                return Err(EtchError::plain(format!(
                    "extra-book-files: {name} leaves the source tree"
                ))
                .with_help("names are relative to the document, and a book stays inside it"));
            }
            files.push(name.to_string());
        }
    }
    Ok(Book {
        directory,
        files: Vec::new(),
        extra: files,
    })
}

fn book_relative(docs: &[PathBuf]) -> Vec<String> {
    let absolute: Vec<PathBuf> = docs
        .iter()
        .map(|doc| doc.canonicalize().unwrap_or_else(|_| doc.clone()))
        .collect();
    let root = metadata::common_ancestor(&absolute);
    absolute
        .iter()
        .map(|doc| {
            doc.strip_prefix(&root)
                .unwrap_or(doc)
                .to_string_lossy()
                .replace('\\', "/")
        })
        .collect()
}

pub(crate) fn declared_book(docs: &[PathBuf]) -> Result<Option<Book>, EtchError> {
    let typst = metadata::binary()?;
    let absolute: Vec<PathBuf> = docs
        .iter()
        .map(|doc| doc.canonicalize().unwrap_or_else(|_| doc.clone()))
        .collect();
    let anchor = metadata::common_ancestor(&absolute);
    for declaration in metadata::declarations(&typst, docs)? {
        if declaration.kind()? == metadata::Kind::Options {
            let mut book = settings(&declaration)?;
            crate::book::settle(&mut book, &typst, docs, &anchor)?;
            return Ok(Some(book));
        }
    }
    Ok(None)
}

pub fn plan(docs: &[PathBuf]) -> Result<Plan, EtchError> {
    let typst = metadata::binary()?;
    let mut blocks: Vec<Block> = Vec::new();
    let mut book: Option<Book> = None;
    let declared = metadata::declarations(&typst, docs)?;
    if declared.is_empty() {
        return Err(EtchError::plain("the document declares no chunks").with_help(
        "import the package and declare them: `#import \"etch.typ\": chunk, file`, then `#chunk(\"name\", ```…```)` or `#file(\"src/main.rs\", ```…```)`",
    ));
    }
    for declaration in declared {
        match declaration.kind()? {
            metadata::Kind::Options => {
                if book.is_some() {
                    return Err(
                        EtchError::plain("the document declares tangle options twice")
                            .with_help("one `#tangle-options(…)` call, with one dict"),
                    );
                }
                book = Some(settings(&declaration)?);
            }
            kind => blocks.push(Block {
                root: kind == metadata::Kind::File,
                name: declaration.name,
                lang: declaration.lang,
                text: declaration.text,
            }),
        }
    }

    let set = ChunkSet::new(&blocks);
    if set.roots().is_empty() {
        let listed = docs
            .iter()
            .map(|doc| doc.display().to_string())
            .collect::<Vec<_>>()
            .join(", ");
        return Err(
            EtchError::plain(format!("no file declarations in {listed}"))
                .with_help("declare one: `#file(\"src/main.rs\", ```…```)`"),
        );
    }

    let referenced: BTreeSet<String> = blocks.iter().flat_map(refs_of).collect();
    let file_names: BTreeSet<&str> = blocks
        .iter()
        .filter(|block| block.root)
        .map(|block| block.name.as_str())
        .collect();
    let mut unreferenced = BTreeSet::new();
    for name in set.names() {
        if !file_names.contains(name) && !referenced.contains(name) {
            unreferenced.insert(name.to_string());
        }
    }

    let mut wordless = BTreeSet::new();
    for name in set.names() {
        let missing = set
            .get(name)
            .is_some_and(|blocks| blocks.iter().any(|block| block.lang.is_none()));
        if missing {
            wordless.insert(name.to_string());
        }
    }

    let mut maps: BTreeMap<PathBuf, EtchMap> = BTreeMap::new();
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
            return Err(EtchError::plain(format!("output {root} is produced twice")));
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

    let mut book_copies = Vec::new();
    let absolute: Vec<PathBuf> = docs
        .iter()
        .map(|doc| doc.canonicalize().unwrap_or_else(|_| doc.clone()))
        .collect();
    let anchor = metadata::common_ancestor(&absolute);
    if let Some(book) = &mut book {
        crate::book::settle(book, &typst, docs, &anchor)?;
    }
    if let Some(settings) = &book {
        book_copies = crate::book::plan(settings, &anchor)?;
        for copy in &book_copies {
            let (dir, name) = split(&copy.to);
            if maps
                .get(Path::new(dir))
                .is_some_and(|map| map.files.contains_key(name))
            {
                return Err(
                    EtchError::plain(format!("the book would overwrite {}", copy.to)).with_help(
                        "a declaration writes that path; change `book-directory` or `extra-book-files`",
                    ),
                );
            }
        }
    }

    Ok(Plan {
        maps,
        texts,
        referenced,
        unreferenced,
        wordless,
        blocks,
        book,
        book_copies,
    })
}

pub fn produced(plan: &Plan) -> BTreeMap<String, BTreeSet<String>> {
    let mut produced: BTreeMap<String, BTreeSet<String>> = plan
        .maps
        .iter()
        .map(|(dir, map)| {
            (
                dir.to_string_lossy().replace('\\', "/"),
                map.files.keys().cloned().collect(),
            )
        })
        .collect();
    for copy in &plan.book_copies {
        let (dir, name) = split(&copy.to);
        produced
            .entry(dir.to_string())
            .or_default()
            .insert(name.to_string());
    }
    produced
}

pub fn inspect(docs: &[PathBuf], out: &Path) -> Result<Outcome, EtchError> {
    let plan = plan(docs)?;
    let mut outcome = Outcome {
        unreferenced: plan.unreferenced.clone(),
        wordless: plan.wordless.clone(),
        ..Outcome::default()
    };

    for (root, text) in &plan.texts {
        let (output, verdict) = look(&plan, root, text, out)?;
        match verdict {
            Disk::Same => outcome.unchanged.push(output),
            _ => outcome.changed.push(output),
        }
    }

    outcome.unaccounted = crate::status::unaccounted(out, &produced(&plan))?;
    Ok(outcome)
}

pub fn run(docs: &[PathBuf], out: &Path, check: bool) -> Result<Outcome, EtchError> {
    let plan = plan(docs)?;
    let documented = book_relative(docs);
    let book = plan.book.clone();
    let mut outcome = Outcome {
        unreferenced: plan.unreferenced.clone(),
        wordless: plan.wordless.clone(),
        ..Outcome::default()
    };

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
        return Err(EtchError::plain(format!("nothing accounts for these files:\n{listed}")).with_help(
            "declare each one in the .etchignore of its directory, or delete it with `etch unaccounted --delete`",
        ));
    }

    for (root, text) in &plan.texts {
        let (output, verdict) = look(&plan, root, text, out)?;
        let dest = out.join(root);

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
    }

    if let Some(book) = &plan.book {
        outcome.carried = crate::book::place(out, &plan.book_copies, check)?;
        outcome.removed = crate::book::sweep(out, &book.directory, &plan.book_copies, check)?;
    }

    if !check {
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
        for (dir, _) in EtchMap::read_all(out) {
            if live.contains(&dir) {
                continue;
            }
            let stale = out.join(&dir).join(MAP_FILE);
            if disk::remove_file(&stale).is_ok() {
                crate::status::prune_empty_dirs(stale.parent().unwrap_or(out), out);
            }
        }
    }
    Ok(outcome)
}

pub fn refs_of(block: &Block) -> Vec<String> {
    let mut names = Vec::new();
    for line in block.text.lines() {
        if let Some((target, _)) = ref_target(line) {
            names.push(target.to_string());
        }
    }
    names
}

fn first_difference(old: &str, new: &str) -> Option<usize> {
    let old_lines: Vec<&str> = old.lines().collect();
    let new_lines: Vec<&str> = new.lines().collect();
    (0..old_lines.len().max(new_lines.len()))
        .find(|&index| old_lines.get(index) != new_lines.get(index))
        .map(|index| index + 1)
}

enum Disk {
    Same,
    Absent,
    Differs {
        line: Option<usize>,
        chunk: Option<String>,
    },
}

fn look(plan: &Plan, root: &str, text: &str, out: &Path) -> Result<(Output, Disk), EtchError> {
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
