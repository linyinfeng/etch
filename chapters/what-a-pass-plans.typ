#import "@local/lp:0.1.0": chunk

= What a pass reports, and what it plans

`Output` is what one file looked like to a pass, `Outcome` is the pass's whole answer —
changed, unchanged, drifted, unaccounted, warnings — and `Plan` is what a pass would do if
it were allowed to. The separation is what lets `--check` be a plan plus a comparison, with
no second implementation of anything.

#chunk("tangle: what a pass reports", ````rust
#[derive(Debug)]
pub struct Output {
    pub root: String,
    pub lines: usize,
    pub lang: Option<String>,
}
````)

#chunk("tangle: what a pass is", ````rust
#[derive(Debug, Default)]
pub struct Outcome {
    pub changed: Vec<Output>,
    pub unchanged: Vec<Output>,
    pub stale: Vec<String>,
    pub unaccounted: Vec<crate::status::Unaccounted>,
    pub warnings: Vec<String>,
}
````)

#chunk("tangle: the plan", ````rust
pub struct Plan {
    pub maps: BTreeMap<PathBuf, LpMap>,
    pub texts: BTreeMap<String, String>,
    pub warnings: Vec<String>,
    pub blocks: Vec<Block>,
    pub book: Option<Book>,
    pub book_copies: Vec<crate::book::Copy>,
}

fn settings(declaration: &metadata::Decl) -> Result<Book, LpError> {
    let value = declaration
        .options
        .clone()
        .unwrap_or(serde_json::Value::Null);
    let table = value
        .as_object()
        .ok_or_else(|| LpError::plain("tangle-options was given something that is not a dict"))?;
    for key in table.keys() {
        if key != "book-directory" && key != "book-files" {
            return Err(LpError::plain(format!("unknown tangle option {key:?}"))
                .with_help("known options: `book-directory`, `book-files`"));
        }
    }
    let directory = table
        .get("book-directory")
        .and_then(|value| value.as_str())
        .ok_or_else(|| {
            LpError::plain("tangle-options needs a `book-directory`")
                .with_help("a string: the directory inside the output that the book is copied into")
        })?
        .to_string();
    let mut files = Vec::new();
    if let Some(value) = table.get("book-files") {
        let list = value
            .as_array()
            .ok_or_else(|| LpError::plain("`book-files` is a list of file names"))?;
        for entry in list {
            let name = entry
                .as_str()
                .ok_or_else(|| LpError::plain("`book-files` is a list of file names"))?;
            if name.starts_with('/') || name.split('/').any(|part| part == "..") {
                return Err(
                    LpError::plain(format!("book-files: {name} leaves the source tree")).with_help(
                        "names are relative to the document, and a book stays inside it",
                    ),
                );
            }
            files.push(name.to_string());
        }
    }
    Ok(Book { directory, files })
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
````)

== Planning a pass

Planning begins by asking for the declarations — the one thing this tool cannot work out for
itself — and turning them into blocks.

#chunk("tangle: ask typst what the document declares", ````rust
let typst = metadata::binary()?;
let mut blocks: Vec<Block> = Vec::new();
let mut book: Option<Book> = None;
let declared = metadata::declarations(&typst, docs)?;
if declared.is_empty() {
    return Err(LpError::plain("the document declares no chunks").with_help(
    "import the package and declare them: `#import \"lp.typ\": chunk, file`, then `#chunk(\"name\", ```…```)` or `#file(\"src/main.rs\", ```…```)`",
));
}
for declaration in declared {
    match declaration.kind()? {
        metadata::Kind::Options => {
            if book.is_some() {
                return Err(LpError::plain("the document declares tangle options twice")
                    .with_help("one `#tangle-options(…)` call, with one dict"));
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
````)

#chunk("tangle: a document with no files", ````rust
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
````)

Fragments nobody references are a warning rather than an error, because a document may
legitimately hold a fragment for a chapter that is still being written — but a fragment that
was declared and then renamed away is almost always a mistake, and this is what catches it.
A declaration with no language tag is warned about for the same kind of reason: the tag is data
that downstream tools read and that this program refuses to guess from a file name, so a gap is
reported rather than quietly filled.

Two places ask the same question about a block — which names does it reference — and it is one function
rather than two readings of the same text: the warning below, and `lp list`, which marks each declaration as
referenced or not.

#chunk("tangle: every name a block references", ````rust
pub fn refs_of(block: &Block) -> Vec<String> {
    let mut names = Vec::new();
    for line in block.text.lines() {
        if let Some((target, _)) = ref_target(line) {
            names.push(target.to_string());
        }
    }
    names
}
````)

#chunk("tangle: fragments nobody uses", ````rust
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
````)

#chunk("tangle: declarations with no language", ````rust
for name in set.names() {
    let missing = set
        .get(name)
        .is_some_and(|blocks| blocks.iter().any(|block| block.lang.is_none()));
    if missing {
        warnings.push(format!("chunk ⟪{name}⟫ is declared without a language"));
    }
}
````)

With the blocks in hand, each declared root is expanded in turn, and the plan records three things about it:
the text to write, the run of declarations that produced each line of it, and the language it was declared
with — carried into the map rather than guessed later from the file name.

#chunk("tangle: check it, and expand it", ````rust
check_output_path(root)?;
let lang = set
    .get(root)
    .and_then(|blocks| blocks.first())
    .and_then(|block| block.lang.clone());
let tangled = expand(&set, root)?;
````)

The path is checked before anything is expanded, and a root declared twice is an error rather than a second
write: two declarations producing one file would make the plan's answer to what is in that file depend on
which of them came last.

#chunk("tangle: the same path twice", ````rust
if !produced.insert(root.to_string()) {
    return Err(LpError::plain(format!("output {root} is produced twice")));
}
````)

#chunk("tangle: record where each line came from", ````rust
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
````)

== Judging the result

`produced` answers the question the ownership check asks: which files, per directory, did
this pass account for? It is derived from the maps rather than kept alongside them, so there
is exactly one answer to that question and no chance of the two disagreeing.

#chunk("tangle: what the documents produce, per directory", ````rust
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
````)
