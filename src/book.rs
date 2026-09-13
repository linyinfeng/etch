use std::path::{Path, PathBuf};

use lopdf::{Dictionary, Document, Object, Stream};

use crate::diag::EtchError;
use crate::disk;
use crate::map::Book;

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

pub fn settle(
    book: &mut Book,
    typst: &Path,
    docs: &[PathBuf],
    anchor: &Path,
) -> Result<(), EtchError> {
    let inputs = crate::metadata::inputs(typst, docs)?;
    book.files = files(book, anchor, &inputs)?;
    Ok(())
}

fn files(book: &Book, anchor: &Path, inputs: &[PathBuf]) -> Result<Vec<String>, EtchError> {
    let mut files: Vec<String> = book.extra.clone();
    for input in inputs {
        let relative = input.strip_prefix(anchor).map_err(|_| {
            EtchError::plain(format!(
                "the document reads {}, which is outside {}",
                input.display(),
                anchor.display()
            ))
            .with_help(
                "a book is everything the document reads, so a book travels only if everything the document reads travels with it",
            )
        })?;
        let name = relative.to_string_lossy().replace('\\', "/");
        if name.starts_with(&format!("{}/", crate::metadata::PACKAGE_ROOT)) {
            continue;
        }
        files.push(name);
    }
    files.sort();
    files.dedup();
    Ok(files)
}

pub fn plan(settings: &Book, anchor: &Path) -> Result<Vec<Copy>, EtchError> {
    let mut copies = Vec::new();
    for name in &settings.files {
        let from = anchor.join(name);
        if !from.is_file() {
            return Err(
                EtchError::plain(format!("extra-book-files: {name} is not a file")).with_help(
                    "names are relative to the document, and the book is a list of them",
                ),
            );
        }
        copies.push(Copy {
            from,
            to: format!("{}/{}", settings.directory.trim_end_matches('/'), name),
        });
    }
    copies.sort_by(|a, b| a.to.cmp(&b.to));
    Ok(copies)
}

const SOURCE_ID: &str = "etch-source";

const MARKER: &str = "the book this document declares";

fn pdf_err(page: &Path) -> impl Fn(lopdf::Error) -> EtchError + '_ {
    move |err| EtchError::plain(format!("{}: {err}", page.display()))
}

pub fn attach(page: &Path, directory: &str, copies: &[Copy]) -> Result<(), EtchError> {
    match page.extension().and_then(|ext| ext.to_str()) {
        Some("html") => attach_html(page, directory, copies),
        Some("pdf") => attach_pdf(page, directory, copies),
        _ => Ok(()),
    }
}

fn attach_html(page: &Path, directory: &str, copies: &[Copy]) -> Result<(), EtchError> {
    let mut files = serde_json::Map::new();
    for copy in copies {
        let bytes = disk::read_bytes(&copy.from)?;
        let text = String::from_utf8(bytes).map_err(|_| {
            EtchError::plain(format!(
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
        "<script type=\"application/json\" id=\"{SOURCE_ID}\" data-etch=\"1\">\n{}\n</script>\n",
        payload.replace('<', "\\u003c")
    );

    let mut html = disk::read(page)?;
    match html.rfind("</body>") {
        Some(at) => html.insert_str(at, &block),
        None => html.push_str(&block),
    }
    disk::write(page, html)
}

fn attach_pdf(page: &Path, directory: &str, copies: &[Copy]) -> Result<(), EtchError> {
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
        .map_err(|err| EtchError::io(page, err))
}

pub fn extract(page: &Path, format: &str, out: &Path) -> Result<usize, EtchError> {
    match format {
        "html" => extract_html(page, out),
        "pdf" => extract_pdf(page, out),
        other => Err(
            EtchError::plain(format!("there is no book to read out of {other}"))
                .with_help("the book rides in an HTML page and in a PDF"),
        ),
    }
}

fn extract_html(page: &Path, out: &Path) -> Result<usize, EtchError> {
    let bytes = disk::read_bytes(page)?;
    let html = String::from_utf8(bytes).map_err(|_| {
        EtchError::plain(format!(
            "{} is not text, so it is not a page",
            page.display()
        ))
        .with_help("the book rides in an HTML rendering, which is text")
    })?;
    let tag = format!("<script type=\"application/json\" id=\"{SOURCE_ID}\"");
    let open = html.rfind(&tag).ok_or_else(|| {
        EtchError::plain(format!(
            "{} carries no book: no {tag}> block",
            page.display()
        ))
        .with_help("only a page this tool wrote carries one")
    })?;
    let body = html[open..]
        .find('>')
        .ok_or_else(|| EtchError::plain(format!("{}: the block never opens", page.display())))?
        + open
        + 1;
    let end = html[body..]
        .find("</script>")
        .ok_or_else(|| EtchError::plain(format!("{}: the block never closes", page.display())))?
        + body;

    let value: serde_json::Value = serde_json::from_str(&html[body..end]).map_err(|err| {
        EtchError::plain(format!(
            "{}: the book is not readable: {err}",
            page.display()
        ))
    })?;
    let files = value
        .get("files")
        .and_then(|files| files.as_object())
        .ok_or_else(|| EtchError::plain(format!("{}: the book has no files", page.display())))?;
    for name in files.keys() {
        if name.starts_with('/') || name.split('/').any(|part| part == "..") {
            return Err(EtchError::plain(format!(
                "{}: {name} would be written outside the output directory",
                page.display()
            )));
        }
    }

    let mut written = 0;
    for (name, text) in files {
        let text = text
            .as_str()
            .ok_or_else(|| EtchError::plain(format!("{name} is not text in this book")))?;
        let path = out.join(name);
        disk::write(&path, text)?;
        written += 1;
    }
    Ok(written)
}

fn extract_pdf(page: &Path, out: &Path) -> Result<usize, EtchError> {
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
) -> Result<usize, EtchError> {
    for (name, _) in &attached {
        if name.starts_with('/') || name.split('/').any(|part| part == "..") {
            return Err(EtchError::plain(format!(
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

pub fn sweep(
    out: &Path,
    directory: &str,
    copies: &[Copy],
    check: bool,
) -> Result<usize, EtchError> {
    let root = out.join(directory.trim_end_matches('/'));
    let listed: Vec<&str> = copies.iter().map(|copy| copy.name(directory)).collect();
    let mut removed = 0;
    let mut parents = Vec::new();
    for (path, relative) in files_under(&root)? {
        if listed.contains(&relative.as_str()) {
            continue;
        }
        if check {
            return Err(EtchError::plain(format!(
                "{} is a copy the book no longer names",
                path.display()
            ))
            .with_help(
                "the book is the list in `tangle-options`; `etch tangle` without `--check` removes it",
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

fn files_under(root: &Path) -> Result<Vec<(PathBuf, String)>, EtchError> {
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

pub fn place(out: &Path, copies: &[Copy], check: bool) -> Result<usize, EtchError> {
    let mut written = 0;
    for copy in copies {
        let path = out.join(&copy.to);
        let bytes = disk::read_bytes(&copy.from)?;
        if disk::read_bytes_ok(&path)?.as_deref() == Some(bytes.as_slice()) {
            continue;
        }
        if check {
            return Err(
                EtchError::plain(format!("{} is out of date", path.display()))
                    .with_help("run `etch tangle` without `--check` to carry the book again"),
            );
        }
        disk::write(&path, &bytes)?;
        written += 1;
    }
    Ok(written)
}
