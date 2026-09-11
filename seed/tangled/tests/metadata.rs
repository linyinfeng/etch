//! The declaration side: what the document says its chunks are.
//!
//! These tests need the `typst` binary (the tool asks the document, it does not
//! read it), so they skip cleanly when it is not on PATH.

use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../lit/lp.typ");

fn typst_available() -> bool {
    Command::new("typst")
        .arg("--version")
        .output()
        .is_ok_and(|output| output.status.success())
}

fn lp(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(args)
        .current_dir(dir)
        .output()
        .expect("run lp")
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).to_string()
}

/// Write the package and a document that imports it.
fn write(dir: &Path, name: &str, body: &str) {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.join(name),
        format!("#import \"lp.typ\": chunk, file, rule\n#show: rule\n{body}"),
    )
    .expect("doc");
}

#[test]
fn a_styling_show_rule_does_not_hide_a_chunk() {
    // The declaration is what the tool reads, and it is emitted before the block
    // is rendered — so even a show rule that throws the element away cannot hide
    // a chunk. (An instrumented show rule could not survive this; a declaration
    // does not care.)
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    write(
        dir.path(),
        "styled.typ",
        "#show raw.where(block: true): it => [styled away]\n\n#chunk(\"styled\", ```py\nprint('styled')\n```)\n",
    );
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "styled.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let report = stdout(&output);
    assert!(report.contains("styled"), "{report}");
    assert!(report.contains("print('styled')"), "{report}");
}

#[test]
fn a_chapter_is_tangled_without_being_listed() {
    // Typst merges #include'd content, so the tool does not need to be told about
    // every file — the document already says.
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    write(dir.path(), "book.typ", "= Book\n#include \"chapter.typ\"\n");
    write(
        dir.path(),
        "chapter.typ",
        "= Chapter\n\n#file(\"src/main.py\", ```py\nprint('from a chapter')\n```)\n",
    );
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "book.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("output"),
        "print('from a chapter')\n"
    );

    // The output line is attributed to the declaration that produced it.
    let mapped = lp(
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
        stdout(&mapped).starts_with("chunk ⟪src/main.py⟫, line 1 of it"),
        "{}",
        stdout(&mapped)
    );
}

#[test]
fn the_document_reports_chunks_no_parser_could_find() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    write(
        dir.path(),
        "dynamic.typ",
        "#file(\"src/main.py\", ```py\n<<part-0>>\n```)\n\n#for i in range(2) [\n  #chunk(\"part-\" + str(i), ```py\n  print(#i)\n  ```)\n]\n",
    );
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "dynamic.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let report = stdout(&output);
    assert!(
        report.contains("part-0") && report.contains("part-1"),
        "{report}"
    );

    // The chunks built by the loop are tangled like any other.
    let tangled = lp(&path, &["tangle", "dynamic.typ", "--out", "out"]);
    assert!(tangled.status.success(), "{}", stderr(&tangled));
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("output"),
        "print(#i)\n"
    );
}

#[test]
fn a_document_that_does_not_evaluate_says_so() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("broken.typ"),
        "= Broken\n\n#undefined-thing(1)\n",
    )
    .expect("doc");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "broken.typ"]);
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(message.contains("did not evaluate"), "{message}");
    assert!(
        message.contains("undefined-thing"),
        "typst's own diagnostic: {message}"
    );
}

#[test]
fn a_document_outside_the_working_directory_can_be_tangled() {
    // The wrapper document has to live where Typst's root can reach the file it
    // includes, so it goes next to the documents rather than in the cwd.
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let documents = TempDir::new().expect("documents");
    write(
        documents.path(),
        "book.typ",
        "#file(\"src/main.py\", ```py\nprint('elsewhere')\n```)\n",
    );

    let workdir = TempDir::new().expect("workdir");
    let doc = documents.path().join("book.typ");
    let out = workdir.path().join("out");
    let output = lp(
        workdir.path(),
        &[
            "tangle",
            doc.to_str().expect("utf8"),
            "--out",
            out.to_str().expect("utf8"),
        ],
    );
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(out.join("src/main.py")).expect("output"),
        "print('elsewhere')\n"
    );

    // And the wrapper is gone again.
    let leftovers: Vec<String> = std::fs::read_dir(documents.path())
        .expect("read_dir")
        .flatten()
        .map(|entry| entry.file_name().to_string_lossy().to_string())
        .filter(|name| name.starts_with(".lp-decl-"))
        .collect();
    assert!(
        leftovers.is_empty(),
        "wrapper files left behind: {leftovers:?}"
    );
}

#[test]
fn a_declaration_of_an_unknown_kind_is_an_error() {
    // Only `chunk` and `file` exist; anything else means the package and the tool
    // disagree, and that must not be read as a fragment.
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("odd.typ"),
        "= Odd\n\n#metadata((lp: \"sideways\", name: \"x\", text: \"y\"))<lp-decl>\n",
    )
    .expect("doc");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "odd.typ"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("unknown declaration kind"),
        "{}",
        stderr(&output)
    );
}

#[test]
fn a_document_without_declarations_says_what_to_do() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("plain.typ"),
        "= Just prose\n\n```py\nprint('not a chunk')\n```\n",
    )
    .expect("doc");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "plain.typ"]);
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(message.contains("declares no chunks"), "{message}");
    assert!(
        message.contains("#file("),
        "the remedy belongs there: {message}"
    );
}
#[test]
fn a_document_needs_nothing_but_itself() {
    // No copy of the package next to it, no environment variable, no git: the tool carries the
    // package and unpacks it for Typst (D21).
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("alone.typ"),
        "#import \"@local/lp:0.1.0\": chunk, file, rule\n#show: rule\n\n#file(\"main.py\", ```py\n<<body>>\n```)\n\n#chunk(\"body\", ```py\nprint('alone')\n```)\n",
    )
    .expect("doc");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "alone.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(path.join("out/main.py")).expect("output"),
        "print('alone')\n"
    );
}
