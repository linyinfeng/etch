use std::path::{Path, PathBuf};
use std::process::{Command, Output, Stdio};

use tempfile::TempDir;

const PKG: &str = include_str!("../package/lib.typ");

fn document(body: &str) -> String {
    format!(
        "#import \"etch.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule\n{body}"
    )
}

const DOC: &str = concat!(
    "\
= Demo

#file(\"main.py\", ```py
",
    "<<imports>>\n",
    "<<body>>\n",
    "\
```)

#chunk(\"imports\", ```py
import sys
```)

#chunk(\"body\", ```py
print('one')
```)

#chunk(\"body\", ```py
print('two')
```)

```text
not a chunk
```
",
);

fn etch(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_etch"))
        .args(args)
        .env("ETCH_LOG", "debug")
        .current_dir(dir)
        .output()
        .expect("run etch")
}

fn write_doc(dir: &Path, name: &str, body: &str) -> String {
    std::fs::write(dir.join("etch.typ"), PKG).expect("package");
    let text = document(body);
    std::fs::write(dir.join(name), &text).expect("doc");
    text
}

fn project(body: &str) -> (TempDir, std::path::PathBuf, String) {
    let dir = TempDir::new().expect("temp dir");
    let text = write_doc(dir.path(), "demo.typ", body);
    let path = dir.path().to_path_buf();
    (dir, path, text)
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).to_string()
}

fn line_of(text: &str, needle: &str) -> usize {
    text.lines()
        .position(|line| line.contains(needle))
        .expect("needle")
        + 1
}

fn under(dir: &Path) -> Vec<PathBuf> {
    let mut all = Vec::new();
    let mut todo = vec![dir.to_path_buf()];
    while let Some(next) = todo.pop() {
        for entry in std::fs::read_dir(&next).expect("read") {
            let path = entry.expect("entry").path();
            let scratch = path.file_name().is_some_and(|name| name == ".etch");
            if path.is_dir() && !scratch {
                todo.push(path);
            } else if path.is_file() {
                all.push(path.strip_prefix(dir).expect("under").to_path_buf());
            }
        }
    }
    all.sort();
    all
}

#[test]
fn tangle_writes_files_with_concat_and_indentation() {
    let (_guard, dir, _) = project(DOC);
    let output = etch(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main.py"),
        "import sys\nprint('one')\nprint('two')\n"
    );
}

#[test]
fn tangle_records_which_chunk_every_line_came_from() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let map: serde_json::Value =
        serde_json::from_str(&std::fs::read_to_string(dir.join("out/.etchmap.json")).expect("map"))
            .expect("json");
    let entry = &map["files"]["main.py"];
    assert_eq!(
        entry["runs"],
        serde_json::json!([
            { "chunk": "imports", "first": 1, "last": 1 },
            { "chunk": "body", "first": 2, "last": 3 },
        ])
    );
    assert!(entry.get("lines").is_none(), "no line numbers are recorded");
    assert!(entry.get("sources").is_none(), "nor source files");
}

#[test]
fn indentation_follows_the_reference_site() {
    let body = "#file(\"main.py\", ```py\nif True:\n    <<body>>\n```)\n\n#chunk(\"body\", ```py\nprint(1)\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main.py"),
        "if True:\n    print(1)\n"
    );
}

#[test]
fn a_chunk_written_indented_in_the_document_is_still_dedented() {
    let body = "#file(\"main.py\", ```py\nif x:\n    <<body>>\n```)\n\n- step one:\n\n  #chunk(\"body\", ```py\n  print(1)\n  print(2)\n  ```)\n";
    let (_guard, dir, _) = project(body);
    let output = etch(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main"),
        "if x:\n    print(1)\n    print(2)\n"
    );
}

#[test]
fn a_chapter_can_hold_the_fragment_another_file_references() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    write_doc(
        dir.path(),
        "chapter.typ",
        "= Chapter one\n\n#chunk(\"greeting\", ```py\nprint('hi')\n```)\n",
    );
    write_doc(
        dir.path(),
        "book.typ",
        "= The program\n\n#file(\"src/main.py\", ```py\n<<greeting>>\n```)\n",
    );
    let path = dir.path().to_path_buf();

    let output = etch(
        &path,
        &["tangle", "book.typ", "chapter.typ", "--out", "out"],
    );
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("main"),
        "print('hi')\n"
    );

    let mapped = etch(
        &path,
        &[
            "map",
            "--file",
            "src/main.py",
            "--line",
            "1",
            "--out",
            "out",
        ],
    );
    assert!(
        stderr(&mapped).contains("chunk ⟪greeting⟫, line 1 of it"),
        "{}",
        stderr(&mapped)
    );

    let no_files = etch(&path, &["tangle", "chapter.typ", "--out", "out2"]);
    assert!(!no_files.status.success());
    assert!(
        stderr(&no_files).contains("no file declarations"),
        "{}",
        stderr(&no_files)
    );
}

#[test]
fn maps_live_next_to_the_files_they_explain() {
    let body =
        "#file(\"a.py\", ```py\nprint('a')\n```)\n\n#file(\"src/b.py\", ```py\nprint('b')\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let root: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(dir.join("out/.etchmap.json")).expect("root map"),
    )
    .expect("json");
    let nested: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(dir.join("out/src/.etchmap.json")).expect("nested map"),
    )
    .expect("json");
    assert!(root["files"].get("a.py").is_some(), "{root}");
    assert!(
        root["files"].get("src/b.py").is_none(),
        "the root map must not index the subtree: {root}"
    );
    assert!(nested["files"].get("b.py").is_some(), "{nested}");

    for file in ["src/b.py", "b.py"] {
        let output = etch(
            &dir,
            &["map", "--file", file, "--line", "1", "--out", "out"],
        );
        assert!(output.status.success(), "{file}: {}", stderr(&output));
        assert!(
            stderr(&output).contains("chunk ⟪src/b.py⟫"),
            "{file}: {}",
            stderr(&output)
        );
    }
}

#[test]
fn an_ambiguous_file_name_is_an_error_not_a_guess() {
    let body = "#file(\"one/b.py\", ```py\nprint('a')\n```)\n\n#file(\"two/b.py\", ```py\nprint('b')\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let output = etch(
        &dir,
        &["map", "--file", "b.py", "--line", "1", "--out", "out"],
    );
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("which map?"),
        "{}",
        stderr(&output)
    );

    let explicit = etch(
        &dir,
        &["map", "--file", "two/b.py", "--line", "1", "--out", "out"],
    );
    assert!(explicit.status.success(), "{}", stderr(&explicit));
}

#[test]
fn check_names_the_chunk_of_the_first_difference() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out", "--check"])
            .status
            .success()
    );

    std::fs::write(dir.join("out/main.py"), "hand edited\n").expect("write");
    let drift = etch(&dir, &["tangle", "demo.typ", "--out", "out", "--check"]);
    assert!(!drift.status.success(), "drift must fail");
    let message = stderr(&drift);
    assert!(
        message.contains("STALE  main.py (line 1, in chunk ⟪imports⟫)"),
        "{message}"
    );

    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out", "--check"])
            .status
            .success()
    );
}

#[test]
fn the_map_follows_the_document_even_when_no_output_byte_changes() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let moved = format!(
        "{}\n{}",
        "#import \"etch.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule", DOC
    );
    std::fs::write(dir.join("demo.typ"), &moved).expect("rewrite");

    let output = etch(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let json: serde_json::Value = serde_json::from_str(&stdout(&output)).expect("one document");
    assert_eq!(
        json["changed"],
        serde_json::json!([]),
        "outputs are unchanged: {}",
        stdout(&output)
    );

    let forward = etch(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(
        stderr(&forward).contains("chunk ⟪body⟫, line 2 of it"),
        "{}",
        stderr(&forward)
    );
}

#[test]
fn dangling_reference_quotes_the_line() {
    let body = "#file(\"main.py\", ```py\n<<missing>>\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = etch(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(
        message.contains("chunk ⟪missing⟫ is not defined"),
        "{message}"
    );
    assert!(
        message.contains("<<missing>>"),
        "the line is quoted: {message}"
    );
    assert!(
        message.contains("in chunk ⟪main.py⟫, line 1 of it"),
        "{message}"
    );
}

#[test]
fn cycle_is_reported() {
    let body = "#file(\"main.py\", ```py\n<<a>>\n```)\n\n#chunk(\"a\", ```py\n<<b>>\n```)\n\n#chunk(\"b\", ```py\n<<a>>\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = etch(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("cycle in chunks"),
        "{}",
        stderr(&output)
    );
}

#[test]
fn an_empty_chunk_is_an_error() {
    let body = "#file(\"main.py\", ```py\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = etch(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(stderr(&output).contains("is empty"), "{}", stderr(&output));
}
#[test]
fn a_declaration_without_a_language_warns() {
    let body = "#file(\"main.py\", ```\nprint(1)\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = etch(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stderr(&output).contains("chunk ⟪main.py⟫ is declared without a language"),
        "{}",
        stderr(&output)
    );
}

#[test]
fn a_file_declaration_can_name_a_nested_path() {
    let body = "#file(\"src/main.rs\", ```rust\nfn main() {}\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = etch(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(dir.join("out/src/main.rs")).expect("nested"),
        "fn main() {}\n"
    );
}

#[test]
fn unsafe_paths_are_rejected() {
    let body = "#file(\"../escape.txt\", ```text\nx\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = etch(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("unsafe chunk name"),
        "{}",
        stderr(&output)
    );
}

#[test]
fn weave_renders_a_document_that_imports_the_package() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("doc.typ"),
        "#import \"etch.typ\": show-rule\n#show: show-rule\n= Woven\n",
    )
    .expect("doc");

    let output = etch(dir.path(), &["weave", "doc.typ", "doc.pdf"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        dir.path().join("doc.pdf").exists(),
        "no document was written"
    );
}

#[test]
fn a_blank_line_in_an_indented_fragment_stays_blank() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#file(\"src/main.rs\", ```rust\nfn outer() {\n    <<inner>>\n}\n```)\n\n#chunk(\"inner\", ```rust\nlet a = 1;\n\nlet b = 2;\n```)\n",
        ),
    )
    .expect("doc");

    let output = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let written = std::fs::read_to_string(dir.path().join("tangled/src/main.rs")).expect("file");

    assert!(
        written.contains("    let a = 1;\n\n    let b = 2;\n"),
        "{written:?}"
    );
    assert!(
        written.lines().all(|line| line == line.trim_end()),
        "an indented fragment left trailing whitespace: {written:?}"
    );
}

#[test]
fn tangling_leaves_only_dot_etch_beside_the_document() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document("#file(\"main.py\", ```py\nprint('x')\n```)\n"),
    )
    .expect("doc");

    let output = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));

    let mut unexpected: Vec<String> = std::fs::read_dir(dir.path())
        .expect("the source directory")
        .flatten()
        .map(|entry| entry.file_name().to_string_lossy().to_string())
        .filter(|name| !["etch.typ", "demo.typ", "tangled", ".etch"].contains(&name.as_str()))
        .collect();
    unexpected.sort();
    assert!(unexpected.is_empty(), "the tool left {unexpected:?} behind");
}

#[test]
fn a_pdf_gives_the_book_back() {
    let dir = TempDir::new().expect("temp dir");
    let document = Path::new(env!("CARGO_MANIFEST_DIR")).join("book/etch.typ");
    let woven = etch(
        dir.path(),
        &["weave", document.to_str().expect("path"), "page.pdf"],
    );
    assert!(woven.status.success(), "{}", stderr(&woven));

    let taken = etch(
        dir.path(),
        &["extract", "--format", "pdf", "page.pdf", "--out", "back"],
    );
    assert!(taken.status.success(), "{}", stderr(&taken));

    let carried = Path::new(env!("CARGO_MANIFEST_DIR")).join("book");
    for name in under(&carried) {
        let back = std::fs::read(dir.path().join("back").join(&name)).expect("back");
        let beside = std::fs::read(carried.join(&name)).expect("beside");
        assert_eq!(back, beside, "{} did not survive the PDF", name.display());
    }
}

#[test]
fn weaving_a_document_with_no_book_carries_none() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("plain.typ"), "= Plain\n\nJust words.\n").expect("doc");

    let woven = etch(
        dir.path(),
        &["weave", "plain.typ", "plain.html", "--features", "html"],
    );
    assert!(woven.status.success(), "{}", stderr(&woven));
    let page = std::fs::read_to_string(dir.path().join("plain.html")).expect("page");
    assert!(
        !page.contains("etch-source"),
        "a document with no book got one"
    );
}

#[test]
fn a_page_gives_the_book_back() {
    let dir = TempDir::new().expect("temp dir");
    let document = Path::new(env!("CARGO_MANIFEST_DIR")).join("book/etch.typ");
    let woven = etch(
        dir.path(),
        &[
            "weave",
            document.to_str().expect("path"),
            "page.html",
            "--features",
            "html",
        ],
    );
    assert!(woven.status.success(), "{}", stderr(&woven));

    let taken = etch(
        dir.path(),
        &["extract", "--format", "html", "page.html", "--out", "back"],
    );
    assert!(taken.status.success(), "{}", stderr(&taken));

    let carried = Path::new(env!("CARGO_MANIFEST_DIR")).join("book");
    for name in under(&carried) {
        let back = std::fs::read(dir.path().join("back").join(&name)).expect("back");
        let beside = std::fs::read(carried.join(&name)).expect("beside");
        assert_eq!(back, beside, "{} did not survive the page", name.display());
    }
}

#[test]
fn reading_weaves_what_the_binary_carries() {
    let dir = TempDir::new().expect("temp dir");
    let output = etch(dir.path(), &["self", "read", "--format", "html"]);
    assert!(output.status.success(), "{}", stderr(&output));

    let path = PathBuf::from(stdout(&output).trim());
    let size = std::fs::metadata(&path)
        .expect("the rendering is there")
        .len();
    assert!(
        size > 10_000,
        "{} looks empty: {size} bytes",
        path.display()
    );
}

#[test]
fn the_book_comes_back_out_whole() {
    let dir = TempDir::new().expect("temp dir");
    let output = etch(dir.path(), &["self", "book", "--out", "unpacked"]);
    assert!(output.status.success(), "{}", stderr(&output));

    let beside = Path::new(env!("CARGO_MANIFEST_DIR")).join("book");
    let names = under(&beside);
    assert!(!names.is_empty(), "the book carries nothing");
    let said: usize = stderr(&output)
        .lines()
        .find(|line| line.contains("files of the book"))
        .and_then(|line| line.split("wrote ").nth(1))
        .and_then(|rest| rest.split_whitespace().next()?.parse().ok())
        .expect("the number of files it says it wrote");
    assert_eq!(
        said,
        names.len(),
        "the count is the whole book, not its top level: {}",
        stderr(&output)
    );
    for name in names {
        let embedded = std::fs::read(dir.path().join("unpacked").join(&name)).expect("carried");
        let carried = std::fs::read(beside.join(&name)).expect("beside");
        assert_eq!(embedded, carried, "{} came back different", name.display());
    }
}

#[test]
fn the_book_is_carried_into_the_tree() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    std::fs::write(dir.path().join("README.md"), "the book\n").expect("readme");
    std::fs::create_dir(dir.path().join("chapters")).expect("dir");
    std::fs::write(dir.path().join("chapters/one.typ"), "= One\n").expect("chapter");
    std::fs::write(dir.path().join("ignored.txt"), "not part of it\n").expect("ignored");
    std::fs::write(dir.path().join(".gitignore"), "ignored.txt\n").expect("gitignore");
    std::fs::create_dir_all(dir.path().join(".etch/leftovers")).expect("dir");
    std::fs::write(
        dir.path().join(".etch/leftovers/lib.typ"),
        "the tool's own state\n",
    )
    .expect("state");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", extra-book-files: (\"demo.typ\", \"chapters/one.typ\", \"README.md\")))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        dir.path().join("tangled/book/demo.typ").exists(),
        "a named file is copied under its own name"
    );
    assert!(
        dir.path().join("tangled/book/chapters/one.typ").exists(),
        "a name with a directory in it keeps its shape"
    );
    assert!(
        dir.path().join("tangled/book/README.md").exists(),
        "and so does a name with no directory at all"
    );
    assert!(
        !dir.path().join("tangled/book/ignored.txt").exists(),
        "a file the list does not name is not part of the book, whatever the source's .gitignore says"
    );
    assert!(
        !dir.path().join("tangled/book/.etch").exists(),
        "and neither is the state the tool keeps for itself"
    );
}

#[test]
fn a_chapter_a_document_includes_travels_with_it() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    std::fs::write(dir.path().join("one.typ"), "= One\n").expect("chapter");
    let body = "#import \"etch.typ\": chunk, file, tangle-options\n#tangle-options((book-directory: \"book\"))\n#include \"one.typ\"\n#file(\"main.py\", ```py\nprint(1)\n```)\n";
    std::fs::write(dir.path().join("demo.typ"), body).expect("doc");

    let first = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(first.status.success(), "{}", stderr(&first));
    assert!(
        dir.path().join("tangled/book/one.typ").exists(),
        "the chapter travelled"
    );

    std::fs::write(dir.path().join("two.typ"), "= Two\n").expect("chapter");
    std::fs::write(
        dir.path().join("demo.typ"),
        format!("{body}#include \"two.typ\"\n"),
    )
    .expect("doc");
    let second = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(second.status.success(), "{}", stderr(&second));
    assert!(
        dir.path().join("tangled/book/two.typ").exists(),
        "a chapter the document started including travels on its own"
    );
}

#[test]
fn a_document_that_reads_outside_itself_cannot_be_carried() {
    let parent = TempDir::new().expect("temp dir");
    let dir = parent.path().join("docs");
    std::fs::create_dir_all(&dir).expect("dir");
    std::fs::write(parent.path().join("shared.typ"), "= Shared\n").expect("chapter");
    std::fs::write(dir.join("etch.typ"), PKG).expect("package");
    std::fs::write(
        dir.join("demo.typ"),
        "#import \"etch.typ\": chunk, file, tangle-options\n#tangle-options((book-directory: \"book\"))\n#include \"../shared.typ\"\n#file(\"main.py\", ```py\nprint(1)\n```)\n",
    )
    .expect("doc");

    let output = etch(parent.path(), &["tangle", "docs/demo.typ"]);
    assert!(
        !output.status.success(),
        "a book cannot leave its directory"
    );
    let message = stderr(&output);
    assert!(message.contains("which is outside"), "{message}");
    assert!(message.contains("shared.typ"), "{message}");
}

#[test]
fn an_unknown_tangle_option_is_refused() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", nonsense: 1))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(!output.status.success(), "an unknown key is not ignored");
    assert!(
        stderr(&output).contains("unknown tangle option"),
        "the package refuses it where it was written: {}",
        stderr(&output)
    );
}

#[test]
fn a_moved_book_copy_leaves_no_empty_directory() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    std::fs::create_dir_all(dir.path().join("one")).expect("dir");
    std::fs::write(dir.path().join("one/x.txt"), "the book\n").expect("chapter");
    let source = |listed: &str| {
        format!(
            "#tangle-options((book-directory: \"book\", extra-book-files: (\"demo.typ\", \"{listed}\")))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n"
        )
    };
    std::fs::write(dir.path().join("demo.typ"), document(&source("one/x.txt"))).expect("doc");
    let first = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(first.status.success(), "{}", stderr(&first));
    assert!(dir.path().join("tangled/book/one/x.txt").exists());

    std::fs::create_dir_all(dir.path().join("two")).expect("dir");
    std::fs::write(dir.path().join("two/x.txt"), "the book\n").expect("chapter");
    std::fs::write(dir.path().join("demo.typ"), document(&source("two/x.txt"))).expect("doc");
    let moved = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(moved.status.success(), "{}", stderr(&moved));

    assert!(dir.path().join("tangled/book/two/x.txt").exists());
    assert!(
        !dir.path().join("tangled/book/one").exists(),
        "the directory the copy moved out of is gone, not left empty"
    );
}

#[test]
fn a_stale_book_copy_is_removed_and_check_refuses_it() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    std::fs::write(dir.path().join("README.md"), "the pointer\n").expect("book file");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", extra-book-files: (\"demo.typ\", \"README.md\")))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");
    let output = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));

    let stale = dir.path().join("tangled/book/old.txt");
    std::fs::write(&stale, "from a generation ago\n").expect("stale");
    let checked = etch(dir.path(), &["tangle", "demo.typ", "--check"]);
    assert!(
        !checked.status.success(),
        "check refuses a tree with a stale copy"
    );
    assert!(
        stderr(&checked).contains("no longer names"),
        "and says why: {}",
        stderr(&checked)
    );

    let again = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(again.status.success(), "{}", stderr(&again));
    assert!(
        !stale.exists(),
        "a plain tangle removes what the list stopped naming"
    );
}

#[test]
fn a_book_name_may_not_leave_the_tree() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", extra-book-files: (\"../outside.txt\",)))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(
        !output.status.success(),
        "a name outside the tree is refused"
    );
    assert!(
        stderr(&output).contains("leaves the source tree"),
        "and it says why: {}",
        stderr(&output)
    );
}

#[test]
fn a_book_without_a_directory_is_an_error() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((extra-book-files: (\"main.py\",)))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("book-directory"),
        "the tool says which key is missing: {}",
        stderr(&output)
    );
}

#[test]
fn a_book_may_not_overwrite_an_output() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("main.py"),
        "a source file the book would carry\n",
    )
    .expect("source");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"src\", extra-book-files: (\"main.py\",)))\n\n#file(\"src/main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(
        !output.status.success(),
        "two writers for one path is refused"
    );
    assert!(
        stderr(&output).contains("would overwrite"),
        "and it says which path: {}",
        stderr(&output)
    );
}

#[test]
fn map_names_the_chunk_a_generated_line_came_from() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let output = etch(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stderr(&output).contains("chunk ⟪body⟫, line 2 of it"),
        "{}",
        stderr(&output)
    );

    let reverse = etch(&dir, &["map", "--typ", "body", "--out", "out"]);
    assert!(reverse.status.success(), "{}", stderr(&reverse));
    assert!(
        stdout(&reverse).contains("\"file\":\"main.py\""),
        "{}",
        stderr(&reverse)
    );
    assert!(
        stderr(&reverse).contains("main.py:3"),
        "{}",
        stderr(&reverse)
    );
}

#[test]
fn the_demo_tangles_and_runs() {
    let demo = Path::new(env!("CARGO_MANIFEST_DIR")).join("examples/demo");
    let dir = TempDir::new().expect("temp dir");
    let document = dir.path().join("examples/demo");
    std::fs::create_dir_all(&document).expect("the document's directory");
    std::fs::copy(demo.join("literate.typ"), document.join("literate.typ")).expect("the document");
    let package = dir.path().join("package");
    std::fs::create_dir_all(&package).expect("the package's directory");
    std::fs::copy(
        Path::new(env!("CARGO_MANIFEST_DIR")).join("package/lib.typ"),
        package.join("lib.typ"),
    )
    .expect("the package");

    let tangled = etch(
        dir.path(),
        &["tangle", "examples/demo/literate.typ", "--out", "build"],
    );
    assert!(tangled.status.success(), "{}", stderr(&tangled));

    let ran = Command::new("sh")
        .arg(dir.path().join("build/greet.sh"))
        .env("NAME", "reader")
        .current_dir(dir.path())
        .output()
        .expect("run the demo");
    assert!(
        ran.status.success(),
        "{}",
        String::from_utf8_lossy(&ran.stderr)
    );
    assert_eq!(String::from_utf8_lossy(&ran.stdout), "hello, reader\n");

    let checked = etch(
        dir.path(),
        &[
            "tangle",
            "examples/demo/literate.typ",
            "--out",
            "build",
            "--check",
        ],
    );
    assert!(checked.status.success(), "{}", stderr(&checked));
}

#[test]
fn tangle_speaks_json_about_what_it_wrote() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("etch.typ"), PKG).expect("package");
    std::fs::write(dir.path().join("README.md"), "the book\n").expect("readme");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", extra-book-files: (\"demo.typ\", \"README.md\")))\n\n#file(\"main.py\", ```py\nprint(1)\n```)\n",
        ),
    )
    .expect("doc");

    let written = etch(dir.path(), &["tangle", "demo.typ"]);
    assert!(written.status.success(), "{}", stderr(&written));
    let json: serde_json::Value =
        serde_json::from_str(&stdout(&written)).expect("one document, and nothing else on stdout");
    assert_eq!(json["version"], 1);
    assert_eq!(json["command"], "tangle");
    assert_eq!(json["changed"][0]["root"], "main.py");
    assert_eq!(json["changed"][0]["lang"], "py");
    assert_eq!(json["unchanged"], serde_json::json!([]));
    assert!(
        json.get("carried").is_none(),
        "the book counts are prose: {}",
        stderr(&written)
    );

    let settled = etch(dir.path(), &["tangle", "demo.typ"]);
    let json: serde_json::Value =
        serde_json::from_str(&stdout(&settled)).expect("one document, and nothing else on stdout");
    assert_eq!(json["changed"], serde_json::json!([]));
    assert_eq!(json["unchanged"][0]["root"], "main.py");
}

#[test]
fn plan_says_what_a_pass_would_do() {
    let (_guard, dir, _) = project(DOC);

    let fresh = etch(&dir, &["plan", "demo.typ", "--out", "out"]);
    assert!(fresh.status.success(), "{}", stderr(&fresh));
    let planned: serde_json::Value = serde_json::from_str(&stdout(&fresh)).expect("one document");
    assert!(
        planned["changed"].as_array().is_some_and(|c| !c.is_empty())
            && planned["unchanged"] == serde_json::json!([]),
        "{}",
        stdout(&fresh)
    );
    assert!(!dir.join("out").exists(), "a plan writes nothing");

    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    let settled = etch(&dir, &["plan", "demo.typ", "--out", "out"]);
    assert!(settled.status.success(), "{}", stderr(&settled));
    let settled_json: serde_json::Value =
        serde_json::from_str(&stdout(&settled)).expect("one document");
    assert!(
        settled_json["unchanged"]
            .as_array()
            .is_some_and(|u| !u.is_empty())
            && settled_json["changed"] == serde_json::json!([]),
        "{}",
        stdout(&settled)
    );

    std::fs::write(dir.join("out/main.py"), "print('drifted')\n").expect("drift");
    let drifted = etch(&dir, &["plan", "demo.typ", "--out", "out"]);
    assert!(
        drifted.status.success(),
        "a plan does not fail on bad news: {}",
        stderr(&drifted)
    );
    assert!(
        stderr(&drifted).contains("would write  main.py"),
        "{}",
        stderr(&drifted)
    );

    std::fs::write(dir.join("out/leftover.py"), "stale\n").expect("stray");
    let reported = etch(&dir, &["plan", "demo.typ", "--out", "out"]);
    assert!(reported.status.success(), "{}", stderr(&reported));
    let json: serde_json::Value = serde_json::from_str(&stdout(&reported)).expect("one document");
    assert_eq!(json["version"], 1);
    assert_eq!(json["command"], "plan");
    assert_eq!(json["unaccounted"][0]["entries"][0], "leftover.py");
}

#[test]
fn map_takes_one_direction() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let nothing = etch(&dir, &["map", "--out", "out"]);
    assert_eq!(nothing.status.code(), Some(2), "{}", stderr(&nothing));
    assert!(stderr(&nothing).contains("--typ"), "{}", stderr(&nothing));

    let line_beside_a_chunk = etch(
        &dir,
        &["map", "--typ", "body", "--line", "3", "--out", "out"],
    );
    assert_eq!(
        line_beside_a_chunk.status.code(),
        Some(2),
        "{}",
        stderr(&line_beside_a_chunk)
    );

    let pair = etch(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(pair.status.success(), "{}", stderr(&pair));
}

#[test]
fn explain_rewrites_diagnostics_to_the_chunk() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let mut child = Command::new(env!("CARGO_BIN_EXE_etch"))
        .args(["explain", "--out", "out"])
        .current_dir(&dir)
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .expect("spawn");

    use std::io::Write;
    child
        .stdin
        .as_mut()
        .expect("stdin")
        .write_all(b"out/main.py:3:1: boom\n")
        .expect("write");
    let output = child.wait_with_output().expect("wait");

    assert!(stdout(&output).contains("out/main.py:3:1: boom"));
    let message = stdout(&output);
    assert!(message.contains("chunk ⟪body⟫, line 2 of it"), "{message}");
}

#[test]
fn list_reports_declarations() {
    let (_guard, dir, _) = project(DOC);
    let output = etch(&dir, &["list", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let listed = stderr(&output);
    assert!(listed.contains("file  ⟪main.py⟫"), "{listed}");
    assert!(listed.contains("frag  ⟪body⟫"), "{listed}");
    assert!(listed.contains("outputs: <main.py>"), "{listed}");
    assert!(
        !listed.contains("not a chunk"),
        "an undeclared block is not a chunk: {listed}"
    );
}

#[test]
fn the_reading_commands_speak_json() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let listed = etch(&dir, &["list", "demo.typ"]);
    assert!(listed.status.success(), "{}", stderr(&listed));
    let list: serde_json::Value = serde_json::from_str(&stdout(&listed)).expect("one document");
    assert_eq!(list["version"], 1);
    assert_eq!(list["command"], "list");
    assert_eq!(list["documents"][0], "demo.typ");
    assert_eq!(list["outputs"][0], "main.py");
    let body = list["declarations"]
        .as_array()
        .expect("declarations")
        .iter()
        .find(|declared| declared["name"] == "body")
        .expect("the body fragment");
    assert_eq!(body["kind"], "chunk");
    assert_eq!(body["lang"], "py");
    assert_eq!(body["referenced"], true);

    let carried = etch(&dir, &["metadata", "demo.typ"]);
    assert!(carried.status.success(), "{}", stderr(&carried));
    let metadata: serde_json::Value =
        serde_json::from_str(&stdout(&carried)).expect("one document");
    assert_eq!(metadata["command"], "metadata");
    let text = metadata["declarations"]
        .as_array()
        .expect("declarations")
        .iter()
        .find(|declared| declared["name"] == "body")
        .expect("the body fragment")["text"]
        .as_str()
        .expect("the whole text, not its first line")
        .to_string();
    assert!(text.contains("print('one')"), "{text}");

    let forward = etch(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(forward.status.success(), "{}", stderr(&forward));
    let mapped: serde_json::Value = serde_json::from_str(&stdout(&forward)).expect("one document");
    assert_eq!(mapped["command"], "map");
    assert_eq!(mapped["file"], "main.py");
    assert_eq!(mapped["chunk"], "body");
    assert_eq!(mapped["exact"], true);

    let past_the_end = etch(
        &dir,
        &["map", "--file", "main.py", "--line", "99", "--out", "out"],
    );
    let nearest: serde_json::Value =
        serde_json::from_str(&stdout(&past_the_end)).expect("one document");
    assert_eq!(nearest["chunk"], "body");
    assert_eq!(
        nearest["exact"], false,
        "a tolerance is not an exact answer"
    );

    let reverse = etch(&dir, &["map", "--typ", "body", "--out", "out"]);
    assert!(reverse.status.success(), "{}", stderr(&reverse));
    let hits: serde_json::Value = serde_json::from_str(&stdout(&reverse)).expect("one document");
    assert_eq!(hits["hits"][0]["file"], "main.py");
    assert_eq!(hits["hits"][0]["line"], 2);
}

#[test]
fn a_closed_pipe_is_not_a_panic() {
    let declared: String = (0..2000)
        .map(|i| format!("#chunk(\"c{i}\", ```py\nprint({i})\n```)\n"))
        .collect();
    let many = format!("#file(\"main.py\", ```py\nprint(0)\n```)\n{declared}");
    let (_guard, dir, _) = project(&many);

    let mut child = Command::new(env!("CARGO_BIN_EXE_etch"))
        .args(["list", "demo.typ"])
        .current_dir(&dir)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("run etch");
    let mut stdout = child.stdout.take().expect("a pipe to read");
    let mut first = [0u8; 64];
    std::io::Read::read_exact(&mut stdout, &mut first).expect("the first bytes");
    drop(stdout);

    let output = child.wait_with_output().expect("wait");
    assert_ne!(
        output.status.code(),
        Some(101),
        "a closed pipe is not a panic: {}",
        stderr(&output)
    );
}

#[test]
fn a_chunk_built_by_code_is_attributed_to_itself() {
    let body = "#for i in range(2) [\n  #file(\"gen-\" + str(i) + \".py\", ```py\n  print(#i)\n  ```)\n]\n";
    let (_guard, dir, _) = project(body);
    let output = etch(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(dir.join("out/gen-0.py").exists());
    assert!(dir.join("out/gen-1.py").exists());

    let mapped = etch(
        &dir,
        &["map", "--file", "gen-0.py", "--line", "1", "--out", "out"],
    );
    assert!(
        stderr(&mapped).contains("chunk ⟪gen-0.py⟫, line 1 of it"),
        "{}",
        stderr(&mapped)
    );
}

#[test]
fn the_declaration_is_where_the_line_lives() {
    let (_guard, _dir, text) = project(DOC);
    assert!(line_of(&text, "#chunk(\"imports\"") > 0);
    assert!(line_of(&text, "print('two')") > 0);
}
