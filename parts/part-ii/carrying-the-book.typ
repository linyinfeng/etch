#import "../../package/lib.typ": chunk, file

= Carrying the book into what it produced

A tree that cannot be read on its own is a build artifact; a tree that carries the document which
produced it is a program with its source of truth beside it. So a document may ask for the copy:

```typst
#tangle-options((book-directory: "book", book-files: ("lp.typ", "parts/part-i/four-claims.typ", …)))
```

Each name is a file, relative to the document, and each one is copied into the output directory under
`book-directory` with the name it had. This document's own settings are the live example. The list is explicit
and not a pattern: it is what the book *is*, it is what a rendering carries, and a
list is something a reader can hold against the directory. The first version matched globs the way a
`.gitignore` matches, walking the source tree to find them — more machinery than a list of names deserves, and
a package could not have read a pattern anyway, since Typst has no `glob`.

The copy is output like everything else: written only when its bytes differ, part of what `--check`
compares, and accounted for by the ownership check rather than reported as a stray. The directory is the
list, in both directions: a copy the list no longer names is stale, removed by the next tangle and refused
by `--check`. That is the one report a `.lpignore` could not have answered — the file was never unaccounted
for, it was simply old — so the book stops producing it rather than explaining it.

#file("src/book.rs", ````rust
<<book: the imports>>

<<book: what the settings ask for>>

<<book: carrying it over>>
````)

#chunk("book: the imports", ````rust
use std::path::{Path, PathBuf};

use lopdf::{Dictionary, Document, Object, Stream};

use crate::diag::LpError;
use crate::disk;
use crate::map::Book;
````)

#chunk("book: what the settings ask for", ````rust
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Copy {
    pub from: PathBuf,
    pub to: String,
}

impl Copy {
    pub fn name<'a>(&'a self, directory: &str) -> &'a str {
        self.to
            .strip_prefix(&format!("{}/", directory.trim_end_matches('/')))
            .unwrap_or(&self.to)
    }
}

pub fn plan(settings: &Book, anchor: &Path) -> Result<Vec<Copy>, LpError> {
    let mut copies = Vec::new();
    for name in &settings.files {
        let from = anchor.join(name);
        if !from.is_file() {
            return Err(LpError::plain(format!("book-files: {name} is not a file"))
                .with_help("names are relative to the document, and the book is a list of them"));
        }
        copies.push(Copy {
            from,
            to: format!("{}/{}", settings.directory.trim_end_matches('/'), name),
        });
    }
    copies.sort_by(|a, b| a.to.cmp(&b.to));
    Ok(copies)
}
````)

The two carriers are explained where weaving is, because that is the command that produces them: a page gets a
data block, a PDF gets attached files, and `lp extract` reads either one back. What is left for this chapter
is the plumbing — the four functions that write and read the two carriers, with the dispatcher and the PDF
dictionary vocabulary they need. That dictionary is the one place in this program that speaks a file format's
own language, and it is why the crate depends on a PDF library at all.

#chunk("book: carrying it over", ````rust
const SOURCE_ID: &str = "lp-source";

const MARKER: &str = "the book this document declares";

fn pdf_err(page: &Path) -> impl Fn(lopdf::Error) -> LpError + '_ {
    move |err| LpError::plain(format!("{}: {err}", page.display()))
}

pub fn attach(page: &Path, directory: &str, copies: &[Copy]) -> Result<(), LpError> {
    match page.extension().and_then(|ext| ext.to_str()) {
        Some("html") => attach_html(page, directory, copies),
        Some("pdf") => attach_pdf(page, directory, copies),
        _ => Ok(()),
    }
}

fn attach_html(page: &Path, directory: &str, copies: &[Copy]) -> Result<(), LpError> {
    let mut files = serde_json::Map::new();
    for copy in copies {
        let bytes = disk::read_bytes(&copy.from)?;
        let text = String::from_utf8(bytes).map_err(|_| {
            LpError::plain(format!(
                "{} is not text, so it cannot ride in a page",
                copy.to
            ))
            .with_help("the book is carried as JSON strings; binary files would need an encoding")
        })?;
        files.insert(
            copy.name(directory).to_string(),
            serde_json::Value::String(text),
        );
    }
    let payload = serde_json::json!({ "version": 1, "files": files }).to_string();

    let block = format!(
        "<script type=\"application/json\" id=\"{SOURCE_ID}\" data-lp=\"1\">\n{}\n</script>\n",
        payload.replace('<', "\\u003c")
    );

    let mut html = disk::read(page)?;
    match html.rfind("</body>") {
        Some(at) => html.insert_str(at, &block),
        None => html.push_str(&block),
    }
    disk::write(page, html)
}

fn attach_pdf(page: &Path, directory: &str, copies: &[Copy]) -> Result<(), LpError> {
    let mut document = Document::load(page).map_err(pdf_err(page))?;
    let mut listed = Vec::new();
    for copy in copies {
        let bytes = disk::read_bytes(&copy.from)?;
        let name = copy.name(directory).to_string();

        let mut file = Dictionary::new();
        file.set("Type", Object::Name(b"EmbeddedFile".to_vec()));
        let stream_id = document.add_object(Stream::new(file, bytes));

        let mut ef = Dictionary::new();
        ef.set("F", Object::Reference(stream_id));
        let mut spec = Dictionary::new();
        spec.set("Type", Object::Name(b"Filespec".to_vec()));
        spec.set("F", Object::string_literal(name.as_str()));
        spec.set("UF", Object::string_literal(name.as_str()));
        spec.set("EF", Object::Dictionary(ef));
        spec.set("Desc", Object::string_literal(MARKER));
        listed.push(Object::string_literal(name.as_str()));
        listed.push(Object::Reference(document.add_object(spec)));
    }

    let mut tree = Dictionary::new();
    tree.set("Names", Object::Array(listed));
    let tree_id = document.add_object(tree);
    let mut names = Dictionary::new();
    names.set("EmbeddedFiles", Object::Reference(tree_id));
    document
        .catalog_mut()
        .map_err(pdf_err(page))?
        .set("Names", Object::Dictionary(names));
    document
        .save(page)
        .map(|_| ())
        .map_err(|err| LpError::io(page, err))
}

pub fn extract(page: &Path, format: &str, out: &Path) -> Result<usize, LpError> {
    match format {
        "html" => extract_html(page, out),
        "pdf" => extract_pdf(page, out),
        other => Err(
            LpError::plain(format!("there is no book to read out of {other}"))
                .with_help("the book rides in an HTML page and in a PDF"),
        ),
    }
}

fn extract_html(page: &Path, out: &Path) -> Result<usize, LpError> {
    let bytes = disk::read_bytes(page)?;
    let html = String::from_utf8(bytes).map_err(|_| {
        LpError::plain(format!(
            "{} is not text, so it is not a page",
            page.display()
        ))
        .with_help("the book rides in an HTML rendering, which is text")
    })?;
    let tag = format!("<script type=\"application/json\" id=\"{SOURCE_ID}\"");
    let open = html.rfind(&tag).ok_or_else(|| {
        LpError::plain(format!(
            "{} carries no book: no {tag}> block",
            page.display()
        ))
        .with_help("only a page this tool wrote carries one")
    })?;
    let body = html[open..]
        .find('>')
        .ok_or_else(|| LpError::plain(format!("{}: the block never opens", page.display())))?
        + open
        + 1;
    let end = html[body..]
        .find("</script>")
        .ok_or_else(|| LpError::plain(format!("{}: the block never closes", page.display())))?
        + body;

    let value: serde_json::Value = serde_json::from_str(&html[body..end]).map_err(|err| {
        LpError::plain(format!(
            "{}: the book is not readable: {err}",
            page.display()
        ))
    })?;
    let files = value
        .get("files")
        .and_then(|files| files.as_object())
        .ok_or_else(|| LpError::plain(format!("{}: the book has no files", page.display())))?;
    for name in files.keys() {
        if name.starts_with('/') || name.split('/').any(|part| part == "..") {
            return Err(LpError::plain(format!(
                "{}: {name} would be written outside the output directory",
                page.display()
            )));
        }
    }

    let mut written = 0;
    for (name, text) in files {
        let text = text
            .as_str()
            .ok_or_else(|| LpError::plain(format!("{name} is not text in this book")))?;
        let path = out.join(name);
        disk::write(&path, text)?;
        written += 1;
    }
    Ok(written)
}

fn extract_pdf(page: &Path, out: &Path) -> Result<usize, LpError> {
    let document = Document::load(page).map_err(pdf_err(page))?;
    let mut attached = Vec::new();
    let embedded = document
        .catalog()
        .map_err(pdf_err(page))?
        .get(b"Names")
        .and_then(|names| names.as_dict()?.get(b"EmbeddedFiles")?.as_reference());
    if let Ok(root) = embedded {
        collect_attached(&document, root, &mut attached).map_err(pdf_err(page))?;
    }
    write_names(page, out, attached)
}

fn collect_attached(
    document: &Document,
    node: lopdf::ObjectId,
    out: &mut Vec<(String, Vec<u8>)>,
) -> Result<(), lopdf::Error> {
    let tree = document.get_dictionary(node)?;
    if let Ok(kids) = tree.get(b"Kids") {
        for kid in kids.as_array()? {
            collect_attached(document, kid.as_reference()?, out)?;
        }
    }
    let Ok(entries) = tree.get(b"Names") else {
        return Ok(());
    };
    for pair in entries.as_array()?.chunks(2) {
        let Some(name) = pair.first().and_then(|name| name.as_str().ok()) else {
            continue;
        };
        let Ok(spec) = document.get_dictionary(pair[1].as_reference()?) else {
            continue;
        };
        let marked = spec
            .get(b"Desc")
            .ok()
            .and_then(|value| value.as_str().ok())
            .is_some_and(|value| value == MARKER.as_bytes());
        if !marked {
            continue;
        }
        let stream = spec.get(b"EF")?.as_dict()?.get(b"F")?.as_reference()?;
        let bytes = document
            .get_object(stream)?
            .as_stream()?
            .decompressed_content()?;
        out.push((String::from_utf8_lossy(name).to_string(), bytes));
    }
    Ok(())
}

fn write_names(
    page: &Path,
    out: &Path,
    attached: Vec<(String, Vec<u8>)>,
) -> Result<usize, LpError> {
    for (name, _) in &attached {
        if name.starts_with('/') || name.split('/').any(|part| part == "..") {
            return Err(LpError::plain(format!(
                "{}: {name} would be written outside the output directory",
                page.display()
            )));
        }
    }
    let mut written = 0;
    for (name, bytes) in attached {
        let path = out.join(&name);
        disk::write(&path, &bytes)?;
        written += 1;
    }
    Ok(written)
}

pub fn sweep(out: &Path, directory: &str, copies: &[Copy], check: bool) -> Result<usize, LpError> {
    let root = out.join(directory.trim_end_matches('/'));
    let listed: Vec<&str> = copies.iter().map(|copy| copy.name(directory)).collect();
    let mut removed = 0;
    let mut parents = Vec::new();
    for (path, relative) in files_under(&root)? {
        if listed.contains(&relative.as_str()) {
            continue;
        }
        if check {
            return Err(LpError::plain(format!(
                "{} is a copy the book no longer names",
                path.display()
            ))
            .with_help(
                "the book is the list in `tangle-options`; `lp tangle` without `--check` removes it",
            ));
        }
        disk::remove_file(&path)?;
        removed += 1;
        let mut parent = path.parent();
        while let Some(dir) = parent {
            if dir == root {
                break;
            }
            parents.push(dir.to_path_buf());
            parent = dir.parent();
        }
    }
    parents.sort_by_key(|dir| std::cmp::Reverse(dir.components().count()));
    for parent in parents {
        if parent != root {
            let _ = disk::remove_dir(&parent);
        }
    }
    Ok(removed)
}

fn files_under(root: &Path) -> Result<Vec<(PathBuf, String)>, LpError> {
    let mut found = Vec::new();
    let mut stack = vec![root.to_path_buf()];
    while let Some(dir) = stack.pop() {
        let Ok(entries) = disk::entries(&dir) else {
            continue;
        };
        for entry in entries {
            let path = entry.path();
            if path
                .components()
                .any(|part| part.as_os_str() == crate::metadata::PACKAGE_ROOT)
            {
                continue;
            }
            if path.is_dir() {
                stack.push(path);
                continue;
            }
            let relative = path
                .strip_prefix(root)
                .unwrap_or(&path)
                .to_string_lossy()
                .replace('\\', "/");
            found.push((path, relative));
        }
    }
    Ok(found)
}

pub fn place(out: &Path, copies: &[Copy], check: bool) -> Result<usize, LpError> {
    let mut written = 0;
    for copy in copies {
        let path = out.join(&copy.to);
        let bytes = disk::read_bytes(&copy.from)?;
        if disk::read_bytes_ok(&path)?.as_deref() == Some(bytes.as_slice()) {
            continue;
        }
        if check {
            return Err(LpError::plain(format!("{} is out of date", path.display()))
                .with_help("run `lp tangle` without `--check` to carry the book again"));
        }
        disk::write(&path, &bytes)?;
        written += 1;
    }
    Ok(written)
}
````)
