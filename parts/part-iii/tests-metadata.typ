#import "../../package/lib.typ": chunk, file

= tests/metadata.rs — what the document declares

The tests for the one thing the tool cannot work out for itself — and for what the tool has to
bring with it while asking. Most of them pin the consequences of asking Typst rather than parsing
the source: a chunk can come from a loop, from
an `#include`d chapter, or from a document whose show rule styles raw blocks away — and all of
those still declare themselves.

#file("tests/metadata.rs", ````rust
<<metadata: the fixtures and helpers>>

<<metadata: a_styling_show_rule_does_not_hide_a_chunk>>

<<metadata: a_chapter_is_tangled_without_being_listed>>

<<metadata: the_document_reports_chunks_no_parser_could_find>>

<<metadata: a_document_that_does_not_evaluate_says_so>>

<<metadata: a_document_outside_the_working_directory_can_be_tangled>>

<<metadata: a_declaration_of_an_unknown_kind_is_an_error>>

<<metadata: a_document_without_declarations_says_what_to_do>>
<<metadata: a_document_needs_nothing_but_itself>>
````)

The cases, in the order they appear:

- `a_styling_show_rule_does_not_hide_a_chunk` — a document whose show rule styles raw blocks away still declares its chunks
- `a_chapter_is_tangled_without_being_listed` — an `#include`d chapter's roots are tangled, and its fragment is visible to its parent
- `the_document_reports_chunks_no_parser_could_find` — chunks built by a loop are reported and tangled — the case no parser could find
- `a_document_that_does_not_evaluate_says_so` — a Typst error is reported as `did not evaluate`, with Typst's own message
- `a_document_outside_the_working_directory_can_be_tangled` — a document outside the working directory works, and no wrapper file is left behind
- `a_declaration_of_an_unknown_kind_is_an_error` — a metadata record with an unknown kind is refused instead of defaulting
- `a_document_without_declarations_says_what_to_do` — a document with no declarations is told to import the package
- `a_document_needs_nothing_but_itself` — a document that imports the package by name tangles in a directory holding nothing else (D21)

#chunk("metadata: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../package/lib.typ");

fn typst_available() -> bool {
    Command::new("typst")
        .arg("--version")
        .output()
        .is_ok_and(|output| output.status.success())
}

fn lp(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(args)
        .env("LP_LOG", "debug")
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

fn write(dir: &Path, name: &str, body: &str) {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.join(name),
        format!(
            "#import \"lp.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule\n{body}"
        ),
    )
    .expect("doc");
}
````)

#chunk("metadata: a_styling_show_rule_does_not_hide_a_chunk", ````rust
#[test]
fn a_styling_show_rule_does_not_hide_a_chunk() {
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
    let report = stderr(&output);
    assert!(report.contains("styled"), "{report}");
    assert!(report.contains("print('styled')"), "{report}");
}
````)

#chunk("metadata: a_chapter_is_tangled_without_being_listed", ````rust
#[test]
fn a_chapter_is_tangled_without_being_listed() {
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
        stderr(&mapped).contains("chunk ⟪src/main.py⟫, line 1 of it"),
        "{}",
        stderr(&mapped)
    );
}
````)

#chunk("metadata: the_document_reports_chunks_no_parser_could_find", ````rust
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
    let report = stderr(&output);
    assert!(
        report.contains("part-0") && report.contains("part-1"),
        "{report}"
    );

    let tangled = lp(&path, &["tangle", "dynamic.typ", "--out", "out"]);
    assert!(tangled.status.success(), "{}", stderr(&tangled));
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("output"),
        "print(#i)\n"
    );
}
````)

#chunk("metadata: a_document_that_does_not_evaluate_says_so", ````rust
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
````)

#chunk(
  "metadata: a_document_outside_the_working_directory_can_be_tangled",
  ````rust
  #[test]
  fn a_document_outside_the_working_directory_can_be_tangled() {
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
  ````,
)

#chunk("metadata: a_declaration_of_an_unknown_kind_is_an_error", ````rust
#[test]
fn a_declaration_of_an_unknown_kind_is_an_error() {
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
````)

#chunk("metadata: a_document_needs_nothing_but_itself", ````rust
#[test]
fn a_document_needs_nothing_but_itself() {
    if !typst_available() {
        eprintln!("skipping: typst is not on PATH");
        return;
    }

    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("alone.typ"),
        "#import \"lp.typ\": chunk, file, show-rule\n#show: show-rule\n\n#file(\"main.py\", ```py\n<<body>>\n```)\n\n#chunk(\"body\", ```py\nprint('alone')\n```)\n",
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
````)

#chunk("metadata: a_document_without_declarations_says_what_to_do", ````rust
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
    assert!(output.status.success(), "{}", stderr(&output));
    let json: serde_json::Value = serde_json::from_str(&stdout(&output)).expect("one document");
    assert_eq!(
        json["declarations"],
        serde_json::json!([]),
        "nothing is still an answer: {}",
        stdout(&output)
    );
}
````)
