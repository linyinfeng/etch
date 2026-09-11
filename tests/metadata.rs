//! The Typst side: what the document says its chunks are.
//!
//! These tests need the `typst` binary (the tool asks the document, it does not
//! read it), so they skip cleanly when it is not on PATH.

use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

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

/// A document that only evaluation can describe: a chapter pulled in with
/// `#include`, a block built inside a loop, and content assembled by code.
const DOC: &str = "\
= Dynamic
#include \"chapter.typ\"
";

const CHAPTER: &str = "\
= Chapter
```py
print('included')
``` <from-chapter>

#for i in range(2) [
```py
print(#i)
``` #label(\"looped-\" + str(i))
]

#for i in range(2) [
  #raw(\"print(\" + str(i) + \")\", lang: \"py\", block: true) #label(\"built-\" + str(i))
]
";

#[test]
fn a_styling_show_rule_does_not_hide_a_chunk() {
    // The tool's own lit.typ styles labelled blocks by *replacing* them, which is
    // what an instrumented show rule cannot survive: it never sees the element.
    // A query reads the element tree, which styling does not change.
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("styled.typ"),
        "#show raw.where(block: true): it => block(fill: luma(240))[styled away]\n         ```py\nprint('styled')\n``` <styled>\n",
    )
    .expect("doc");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "styled.typ"]);
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    let report = stdout(&output);
    assert!(report.contains("styled"), "{report}");
    assert!(report.contains("print('styled')"), "{report}");
}

#[test]
fn a_chapter_is_tangled_without_being_listed() {
    // Typst merges #include'd content, so the tool no longer needs to be told
    // about every file — the document already says.
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(
        dir.path().join("book.typ"),
        "= Book\n#include \"chapter.typ\"\n",
    )
    .expect("book");
    std::fs::write(
        dir.path().join("chapter.typ"),
        "= Chapter\n\n```py\nprint('from a chapter')\n``` #label(\"src/main.py\")\n",
    )
    .expect("chapter");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "book.typ", "--out", "out"]);
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("output"),
        "print('from a chapter')\n"
    );

    // And the line is traced to the chapter file, not to the book that includes it.
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
    assert_eq!(
        stdout(&mapped).lines().next(),
        Some("chapter.typ:4"),
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
    std::fs::write(dir.path().join("book.typ"), DOC).expect("book");
    std::fs::write(dir.path().join("chapter.typ"), CHAPTER).expect("chapter");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["metadata", "book.typ"]);
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    let report = stdout(&output);

    // The included chapter's chunk is part of the document …
    assert!(report.contains("from-chapter"), "{report}");
    // … the loop's blocks are, one event each …
    assert!(
        report.contains("looped-0") && report.contains("looped-1"),
        "{report}"
    );
    // … and so is content that exists in no source line at all.
    assert!(
        report.contains("built-0") && report.contains("built-1"),
        "{report}"
    );
    assert!(
        report.contains("print(0)") && report.contains("print(1)"),
        "{report}"
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
    let message = String::from_utf8_lossy(&output.stderr);
    assert!(message.contains("did not evaluate"), "{message}");
    assert!(
        message.contains("undefined-thing"),
        "typst's own diagnostic: {message}"
    );
}
