//! End-to-end tests: they run the real binary against throwaway documents.

use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../lit/lp.typ");

/// A document in the real authoring form: the package is imported, its rules are
/// installed, and the body declares chunks.
fn document(body: &str) -> String {
    format!("#import \"lp.typ\": chunk, file, rule\n#show: rule\n{body}")
}

/// A document with one file declaration, a shared fragment, a fragment written in
/// two pieces, and a code sample that is not a chunk at all.
const DOC: &str = "\
= Demo

#file(\"main.py\", ```py
<<imports>>
<<body>>
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
";

fn lp(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(args)
        .current_dir(dir)
        .output()
        .expect("run lp")
}

/// Write a document plus the package it imports; returns the text that was
/// written, so line assertions are about the real file.
fn write_doc(dir: &Path, name: &str, body: &str) -> String {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
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

#[test]
fn tangle_writes_files_with_concat_and_indentation() {
    let (_guard, dir, _) = project(DOC);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));

    let main = std::fs::read_to_string(dir.join("out/main.py")).expect("main.py");
    assert_eq!(main, "import sys\nprint('one')\nprint('two')\n");
}

#[test]
fn tangle_records_where_every_line_came_from() {
    let (_guard, dir, text) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let map: serde_json::Value =
        serde_json::from_str(&std::fs::read_to_string(dir.join("out/.lpmap.json")).expect("map"))
            .expect("json");
    let lines = map["files"]["main.py"]["lines"].as_array().expect("lines");
    let sources = map["files"]["main.py"]["sources"]
        .as_array()
        .expect("sources");
    assert_eq!(sources, &[serde_json::json!("demo.typ")]);

    // Output line 3 comes from the second <body> declaration, not from the
    // reference; the third element names the source file it lives in.
    let expected = line_of(&text, "print('two')");
    assert_eq!(lines[2], serde_json::json!([3, expected, 0]));
}

#[test]
fn indentation_follows_the_reference_site() {
    let body = "#file(\"main.py\", ```py\nif True:\n    <<body>>\n```)\n\n#chunk(\"body\", ```py\nprint(1)\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    let main = std::fs::read_to_string(dir.join("out/main.py")).expect("main.py");
    assert_eq!(main, "if True:\n    print(1)\n");
}

#[test]
fn a_chunk_written_indented_in_the_document_is_still_dedented() {
    // Typst removes the indentation a block shares with its surroundings, and the
    // reference site adds its own.
    let body = "- step one:\n\n  #chunk(\"body\", ```py\n  print(1)\n  print(2)\n  ```)\n\n#file(\"main.py\", ```py\nif x:\n    <<body>>\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main"),
        "if x:\n    print(1)\n    print(2)\n"
    );
}

#[test]
fn a_chapter_can_hold_the_fragment_another_file_references() {
    // The documents are chapters of one program: prose in one, the fragment in
    // another, the file that pulls them together in a third.
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    write_doc(
        dir.path(),
        "chapter.typ",
        "= Chapter one\n\n#chunk(\"greeting\", ```py\nprint('hi')\n```)\n",
    );
    let book = write_doc(
        dir.path(),
        "book.typ",
        "= The program\n\n#file(\"src/main.py\", ```py\n<<greeting>>\n```)\n",
    );
    let path = dir.path().to_path_buf();

    let output = lp(
        &path,
        &["tangle", "book.typ", "chapter.typ", "--out", "out"],
    );
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("main"),
        "print('hi')\n"
    );

    // The line came from chapter.typ, and the map says so.
    let map: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(path.join("out/src/.lpmap.json")).expect("map"),
    )
    .expect("json");
    let entry = &map["files"]["main.py"];
    assert_eq!(entry["sources"], serde_json::json!(["chapter.typ"]));

    let chapter = std::fs::read_to_string(path.join("chapter.typ")).expect("chapter");
    assert_eq!(
        entry["lines"][0],
        serde_json::json!([1, line_of(&chapter, "print('hi')"), 0])
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
    let expected = format!("chapter.typ:{}", line_of(&chapter, "print('hi')"));
    assert_eq!(stdout(&mapped).lines().next(), Some(expected.as_str()));

    // A run with no file declarations anywhere is still an error.
    let no_files = lp(&path, &["tangle", "chapter.typ", "--out", "out2"]);
    assert!(!no_files.status.success());
    assert!(
        stderr(&no_files).contains("no root chunks"),
        "{}",
        stderr(&no_files)
    );

    assert!(line_of(&book, "#file(\"src/main.py\"") > 0);
}

#[test]
fn maps_live_next_to_the_files_they_explain() {
    let body =
        "#file(\"a.py\", ```py\nprint('a')\n```)\n\n#file(\"src/b.py\", ```py\nprint('b')\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let root: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(dir.join("out/.lpmap.json")).expect("root map"),
    )
    .expect("json");
    let nested: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(dir.join("out/src/.lpmap.json")).expect("nested map"),
    )
    .expect("json");
    assert!(root["files"].get("a.py").is_some(), "{root}");
    assert!(
        root["files"].get("src/b.py").is_none(),
        "the root map must not index the subtree: {root}"
    );
    assert!(nested["files"].get("b.py").is_some(), "{nested}");

    for file in ["src/b.py", "b.py"] {
        let output = lp(
            &dir,
            &["map", "--file", file, "--line", "1", "--out", "out"],
        );
        assert!(output.status.success(), "{file}: {}", stderr(&output));
        assert!(
            stdout(&output).starts_with("demo.typ:"),
            "{file}: {}",
            stdout(&output)
        );
    }
}

#[test]
fn an_ambiguous_file_name_is_an_error_not_a_guess() {
    let body = "#file(\"one/b.py\", ```py\nprint('a')\n```)\n\n#file(\"two/b.py\", ```py\nprint('b')\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let output = lp(
        &dir,
        &["map", "--file", "b.py", "--line", "1", "--out", "out"],
    );
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("which line map?"),
        "{}",
        stderr(&output)
    );

    let explicit = lp(
        &dir,
        &["map", "--file", "two/b.py", "--line", "1", "--out", "out"],
    );
    assert!(explicit.status.success(), "{}", stderr(&explicit));
}

#[test]
fn check_reports_drift_with_the_typ_line() {
    let (_guard, dir, text) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let check = lp(&dir, &["tangle", "demo.typ", "--out", "out", "--check"]);
    assert!(
        check.status.success(),
        "clean run must succeed: {}",
        stderr(&check)
    );

    std::fs::write(dir.join("out/main.py"), "hand edited\n").expect("write");
    let drift = lp(&dir, &["tangle", "demo.typ", "--out", "out", "--check"]);
    assert!(!drift.status.success(), "drift must fail");
    let message = stderr(&drift);
    assert!(message.contains("STALE  main.py"), "{message}");
    // The first difference is line 1, which came from the <imports> declaration.
    assert!(
        message.contains(&format!("demo.typ:{}", line_of(&text, "import sys"))),
        "{message}"
    );

    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out", "--check"])
            .status
            .success()
    );
}

#[test]
fn the_map_follows_the_document_even_when_no_output_byte_changes() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    // A line of prose above the declarations shifts every mapping and changes no
    // generated byte: the outputs stay untouched, the map must not.
    let moved = format!(
        "{}\n{}",
        "#import \"lp.typ\": chunk, file, rule\n#show: rule", DOC
    );
    std::fs::write(dir.join("demo.typ"), &moved).expect("rewrite");

    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        !stdout(&output).contains("wrote"),
        "outputs are unchanged: {}",
        stdout(&output)
    );

    let forward = lp(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    let expected = line_of(&moved, "print('two')");
    assert!(
        stdout(&forward).starts_with(&format!("demo.typ:{expected}")),
        "stale map: {}",
        stdout(&forward)
    );
}

#[test]
fn dangling_reference_points_at_the_reference_line() {
    let body = "#file(\"main.py\", ```py\n<<missing>>\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(
        message.contains("chunk <<missing>> is not defined"),
        "{message}"
    );
    assert!(message.contains("demo.typ:4"), "{message}");
}

#[test]
fn cycle_is_reported() {
    let body = "#file(\"main.py\", ```py\n<<b>>\n```)\n\n#chunk(\"a\", ```py\n<<b>>\n```)\n\n#chunk(\"b\", ```py\n<<a>>\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("cycle in chunks"),
        "{}",
        stderr(&output)
    );
}

#[test]
fn a_file_declaration_can_name_a_nested_path() {
    let body = "#file(\"src/main.rs\", ```rust\nfn main() {}\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
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
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("unsafe chunk name"),
        "{}",
        stderr(&output)
    );
}

#[test]
fn map_translates_a_generated_line_back_to_the_document() {
    let (_guard, dir, text) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let output = lp(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(output.status.success(), "{}", stderr(&output));
    let expected = format!("demo.typ:{}", line_of(&text, "print('two')"));
    assert_eq!(stdout(&output).lines().next(), Some(expected.as_str()));
}

#[test]
fn explain_rewrites_diagnostics_to_the_document() {
    let (_guard, dir, text) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let mut child = Command::new(env!("CARGO_BIN_EXE_lp"))
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
    let message = stderr(&output);
    assert!(
        message.contains(&format!("demo.typ:{}", line_of(&text, "print('two')"))),
        "{message}"
    );
}

#[test]
fn list_reports_declarations() {
    let (_guard, dir, _) = project(DOC);
    let output = lp(&dir, &["list", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let listed = stdout(&output);
    assert!(listed.contains("root  <main.py>"), "{listed}");
    assert!(listed.contains("outputs: <main.py>"), "{listed}");
    assert!(
        !listed.contains("not a chunk"),
        "an undeclared block is not a chunk: {listed}"
    );
}

#[test]
fn a_chunk_built_by_code_has_no_line_and_says_so() {
    // The declaration is written once, inside a loop: the tool must not invent a
    // line for the chunks that come out of it.
    let body = "#for i in range(2) [\n  #file(\"gen-\" + str(i) + \".py\", ```py\n  print(#i)\n  ```)\n]\n";
    let (_guard, dir, text) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(dir.join("out/gen-0.py").exists());
    assert!(dir.join("out/gen-1.py").exists());

    let mapped = lp(
        &dir,
        &["map", "--file", "gen-0.py", "--line", "1", "--out", "out"],
    );
    let reported = stdout(&mapped);
    // Either the loop it was built in, or an honest "no source line".
    assert!(
        reported.contains(&format!("demo.typ:{}", line_of(&text, "#file(\"gen-\"")))
            || reported.contains("built by the document"),
        "{reported}"
    );
}
