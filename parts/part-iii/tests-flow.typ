#import "../../package/lib.typ": chunk, file

= tests/flow.rs — what tangling does

The largest file, and the one that pins the mechanism: a fragment shared by two files, a name
declared twice, indentation at the reference site, the map, the three failures, and the two
commands that read the result back. Most of the cases share one fixture, because the point is
what the *same* document produces in different situations.

One helper walks a directory, because the round-trip cases are about the whole book, and comparing a
list of names would be comparing a list that goes stale. The walk skips `.lp`: that is the one name the
tool writes beside a document, and the only thing under `book/` that is not part of the book.

#file("tests/flow.rs", ````rust
<<flow: the fixtures and helpers>>

<<flow: tangle_writes_files_with_concat_and_indentation>>

<<flow: tangle_records_which_chunk_every_line_came_from>>

<<flow: indentation_follows_the_reference_site>>

<<flow: a_chunk_written_indented_in_the_document_is_still_dedented>>

<<flow: a_chapter_can_hold_the_fragment_another_file_references>>

<<flow: maps_live_next_to_the_files_they_explain>>

<<flow: an_ambiguous_file_name_is_an_error_not_a_guess>>

<<flow: check_names_the_chunk_of_the_first_difference>>

<<flow: the_map_follows_the_document_even_when_no_output_byte_changes>>

<<flow: dangling_reference_quotes_the_line>>

<<flow: cycle_is_reported>>

<<flow: an_empty_chunk_is_an_error>>
<<flow: a_declaration_without_a_language_warns>>

<<flow: a_file_declaration_can_name_a_nested_path>>

<<flow: unsafe_paths_are_rejected>>

<<flow: weave_renders_a_document_that_imports_the_package>>

<<flow: a_blank_line_in_an_indented_fragment_stays_blank>>

<<flow: tangling_leaves_only_dot_lp_beside_the_document>>

<<flow: a_pdf_gives_the_book_back>>

<<flow: weaving_a_document_with_no_book_carries_none>>

<<flow: a_page_gives_the_book_back>>

<<flow: reading_weaves_what_the_binary_carries>>

<<flow: the_book_comes_back_out_whole>>

<<flow: the_book_is_carried_into_the_tree>>

<<flow: a_chapter_a_document_includes_travels_with_it>>

<<flow: a_document_that_reads_outside_itself_cannot_be_carried>>

<<flow: an_unknown_tangle_option_is_refused>>

<<flow: a_moved_book_copy_leaves_no_empty_directory>>

<<flow: a_stale_book_copy_is_removed_and_check_refuses_it>>

<<flow: a_book_name_may_not_leave_the_tree>>

<<flow: a_book_without_a_directory_is_an_error>>

<<flow: a_book_may_not_overwrite_an_output>>

<<flow: map_names_the_chunk_a_generated_line_came_from>>

<<flow: the_demo_tangles_and_runs>>

<<flow: tangle_speaks_json_about_what_it_wrote>>

<<flow: plan_says_what_a_pass_would_do>>

<<flow: map_takes_one_direction>>

<<flow: explain_rewrites_diagnostics_to_the_chunk>>

<<flow: list_reports_declarations>>

<<flow: the_reading_commands_speak_json>>

<<flow: a_closed_pipe_is_not_a_panic>>

<<flow: a_chunk_built_by_code_is_attributed_to_itself>>

<<flow: the_declaration_is_where_the_line_lives>>
````)

The cases, in the order they appear:

- `tangle_writes_files_with_concat_and_indentation` — a shared fragment and a name declared twice land in one file, with the reference's indentation
- `tangle_records_which_chunk_every_line_came_from` — the map names a chunk and a run for every output line, and records no source positions
- `indentation_follows_the_reference_site` — the same chunk indents differently at two reference sites
- `a_chunk_written_indented_in_the_document_is_still_dedented` — a declaration written inside a list item contributes flush-left text
- `a_chapter_can_hold_the_fragment_another_file_references` — a fragment declared in a second document is visible to the first
- `maps_live_next_to_the_files_they_explain` — one map per directory, not one at the top
- `an_ambiguous_file_name_is_an_error_not_a_guess` — a bare name that two maps could explain is refused, with the candidates listed
- `check_names_the_chunk_of_the_first_difference` — drift is reported as the first differing line and the chunk responsible for it
- `the_map_follows_the_document_even_when_no_output_byte_changes` — moving prose rewrites the map even when no output byte moves
- `dangling_reference_quotes_the_line` — an undefined name is an error that quotes the line and names the chunk it was in
- `cycle_is_reported` — the error is the chain, not a bare `cycle detected`
- `an_empty_chunk_is_an_error` — a declaration with no body is refused rather than tangled away
- `a_declaration_without_a_language_warns` — a fence with no language tag is reported, and the pass still succeeds
- `a_file_declaration_can_name_a_nested_path` — `src/main.rs` is created under the output directory, directories and all
- `unsafe_paths_are_rejected` — `../escape.txt` and its relatives cannot leave the output directory
- `map_names_the_chunk_a_generated_line_came_from` — `lp map --file --line` answers with the chunk and how far into it the line is
- `map_takes_one_direction` — an empty `lp map`, and a `--line` beside `--typ`, are refused by the surface (exit 2) rather than by the arm
- `explain_rewrites_diagnostics_to_the_chunk` — a `file:line:col:` line is echoed unchanged and annotated on stderr
- `list_reports_declarations` — `lp list` prints every declaration, marks the unreferenced ones, and lists the outputs; a code block in prose is not one
- `a_closed_pipe_is_not_a_panic` — a reader that stops reading (`| head`) ends the tool quietly instead of panicking on a broken pipe
- `the_demo_tangles_and_runs` — the small example this book declares tangles from its own document, runs, and prints what it promised
- `plan_says_what_a_pass_would_do` — `lp plan` writes nothing, says `would write` then `nothing to do`, and does not fail on bad news
- `tangle_speaks_json_about_what_it_wrote` — a pass that wrote reports what it wrote as one JSON document, and the book counts stay in the log
- `weave_renders_a_document_that_imports_the_package` — `lp weave` renders a document whose import resolves only through the package this tool unpacks
- `the_book_is_carried_into_the_tree` — the settings put the book beside its output, under the names it lists, and nothing else
- `a_chapter_a_document_includes_travels_with_it` — a chapter added to the include list travels into the book with no change to the settings
- `a_document_that_reads_outside_itself_cannot_be_carried` — a document whose reading reaches past its own directory is refused, and the file it reached for is named
- `a_book_name_may_not_leave_the_tree` — a name in `extra-book-files` that climbs out of the source tree is refused
- `a_stale_book_copy_is_removed_and_check_refuses_it` — the book directory is the list: a copy it no longer names is removed by a tangle and refused by `--check`
- `a_moved_book_copy_leaves_no_empty_directory` — a copy that moves to a different directory takes its old one with it, empty or not
- `the_book_comes_back_out_whole` — `lp self book --out` writes exactly the book the binary carries, byte for byte
- `reading_weaves_what_the_binary_carries` — `lp self read --format html` weaves the embedded document and leaves a rendering behind
- `a_page_gives_the_book_back` — `lp weave` puts the book the document declares into the HTML it renders, and `lp extract` gets it back byte for byte
- `weaving_a_document_with_no_book_carries_none` — a document that declares nothing still weaves: no block, and no complaint either
- `a_pdf_gives_the_book_back` — the PDF carries the book as attached files, and `lp extract --format pdf` gets it back byte for byte
- `tangling_leaves_only_dot_lp_beside_the_document` — everything the tool writes beside a document is under `.lp`: the package, the wrapper, all of it
- `a_blank_line_in_an_indented_fragment_stays_blank` — an indented fragment's blank line is written blank, not as a line of spaces
- `an_unknown_tangle_option_is_refused` — the package refuses a key it does not know, at the line that wrote it
- `a_book_without_a_directory_is_an_error` — asking for a book without saying where it goes is refused by the tool
- `a_book_may_not_overwrite_an_output` — a book that would land on a declared file is refused while planning
- `a_chunk_built_by_code_is_attributed_to_itself` — roots declared by a loop are attributed to the declarations the loop produced
- `the_declaration_is_where_the_line_lives` — the answer includes the `rg` command that finds the declaration

#chunk("flow: the fixtures and helpers", ````rust
use std::path::{Path, PathBuf};
use std::process::{Command, Output, Stdio};

use tempfile::TempDir;

const PKG: &str = include_str!("../package/lib.typ");

fn document(body: &str) -> String {
    format!("#import \"lp.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule\n{body}")
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

fn lp(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(args)
        .env("LP_LOG", "debug")
        .current_dir(dir)
        .output()
        .expect("run lp")
}

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

fn under(dir: &Path) -> Vec<PathBuf> {
    let mut all = Vec::new();
    let mut todo = vec![dir.to_path_buf()];
    while let Some(next) = todo.pop() {
        for entry in std::fs::read_dir(&next).expect("read") {
            let path = entry.expect("entry").path();
            let scratch = path.file_name().is_some_and(|name| name == ".lp");
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
````)

#chunk("flow: tangle_writes_files_with_concat_and_indentation", ````rust
#[test]
fn tangle_writes_files_with_concat_and_indentation() {
    let (_guard, dir, _) = project(DOC);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main.py"),
        "import sys\nprint('one')\nprint('two')\n"
    );
}
````)

#chunk("flow: tangle_records_which_chunk_every_line_came_from", ````rust
#[test]
fn tangle_records_which_chunk_every_line_came_from() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let map: serde_json::Value =
        serde_json::from_str(&std::fs::read_to_string(dir.join("out/.lpmap.json")).expect("map"))
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
````)

#chunk("flow: indentation_follows_the_reference_site", ````rust
#[test]
fn indentation_follows_the_reference_site() {
    let body = "#file(\"main.py\", ```py\nif True:\n    <<body>>\n```)\n\n#chunk(\"body\", ```py\nprint(1)\n```)\n";
    let (_guard, dir, _) = project(body);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main.py"),
        "if True:\n    print(1)\n"
    );
}
````)

#chunk(
  "flow: a_chunk_written_indented_in_the_document_is_still_dedented",
  ````rust
  #[test]
  fn a_chunk_written_indented_in_the_document_is_still_dedented() {
      let body = "#file(\"main.py\", ```py\nif x:\n    <<body>>\n```)\n\n- step one:\n\n  #chunk(\"body\", ```py\n  print(1)\n  print(2)\n  ```)\n";
      let (_guard, dir, _) = project(body);
      let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
      assert!(output.status.success(), "{}", stderr(&output));
      assert_eq!(
          std::fs::read_to_string(dir.join("out/main.py")).expect("main"),
          "if x:\n    print(1)\n    print(2)\n"
      );
  }
  ````,
)

#chunk("flow: a_chapter_can_hold_the_fragment_another_file_references", ````rust
#[test]
fn a_chapter_can_hold_the_fragment_another_file_references() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
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

    let output = lp(
        &path,
        &["tangle", "book.typ", "chapter.typ", "--out", "out"],
    );
    assert!(output.status.success(), "{}", stderr(&output));
    assert_eq!(
        std::fs::read_to_string(path.join("out/src/main.py")).expect("main"),
        "print('hi')\n"
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
        stderr(&mapped).contains("chunk ⟪greeting⟫, line 1 of it"),
        "{}",
        stderr(&mapped)
    );

    let no_files = lp(&path, &["tangle", "chapter.typ", "--out", "out2"]);
    assert!(!no_files.status.success());
    assert!(
        stderr(&no_files).contains("no file declarations"),
        "{}",
        stderr(&no_files)
    );
}
````)

#chunk("flow: maps_live_next_to_the_files_they_explain", ````rust
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
            stderr(&output).contains("chunk ⟪src/b.py⟫"),
            "{file}: {}",
            stderr(&output)
        );
    }
}
````)

#chunk("flow: an_ambiguous_file_name_is_an_error_not_a_guess", ````rust
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
        stderr(&output).contains("which map?"),
        "{}",
        stderr(&output)
    );

    let explicit = lp(
        &dir,
        &["map", "--file", "two/b.py", "--line", "1", "--out", "out"],
    );
    assert!(explicit.status.success(), "{}", stderr(&explicit));
}
````)

#chunk("flow: check_names_the_chunk_of_the_first_difference", ````rust
#[test]
fn check_names_the_chunk_of_the_first_difference() {
    let (_guard, dir, _) = project(DOC);
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

    std::fs::write(dir.join("out/main.py"), "hand edited\n").expect("write");
    let drift = lp(&dir, &["tangle", "demo.typ", "--out", "out", "--check"]);
    assert!(!drift.status.success(), "drift must fail");
    let message = stderr(&drift);
    assert!(
        message.contains("STALE  main.py (line 1, in chunk ⟪imports⟫)"),
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
````)

#chunk(
  "flow: the_map_follows_the_document_even_when_no_output_byte_changes",
  ````rust
  #[test]
  fn the_map_follows_the_document_even_when_no_output_byte_changes() {
      let (_guard, dir, _) = project(DOC);
      assert!(
          lp(&dir, &["tangle", "demo.typ", "--out", "out"])
              .status
              .success()
      );

      let moved = format!(
          "{}\n{}",
          "#import \"lp.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule", DOC
      );
      std::fs::write(dir.join("demo.typ"), &moved).expect("rewrite");

      let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
      assert!(output.status.success(), "{}", stderr(&output));
      let json: serde_json::Value = serde_json::from_str(&stdout(&output)).expect("one document");
      assert_eq!(
          json["changed"],
          serde_json::json!([]),
          "outputs are unchanged: {}",
          stdout(&output)
      );

      let forward = lp(
          &dir,
          &["map", "--file", "main.py", "--line", "3", "--out", "out"],
      );
      assert!(
          stderr(&forward).contains("chunk ⟪body⟫, line 2 of it"),
          "{}",
          stderr(&forward)
      );
  }
  ````,
)

#chunk("flow: dangling_reference_quotes_the_line", ````rust
#[test]
fn dangling_reference_quotes_the_line() {
    let body = "#file(\"main.py\", ```py\n<<missing>>\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
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
````)

#chunk("flow: cycle_is_reported", ````rust
#[test]
fn cycle_is_reported() {
    let body = "#file(\"main.py\", ```py\n<<a>>\n```)\n\n#chunk(\"a\", ```py\n<<b>>\n```)\n\n#chunk(\"b\", ```py\n<<a>>\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("cycle in chunks"),
        "{}",
        stderr(&output)
    );
}
````)

#chunk("flow: a_declaration_without_a_language_warns", ````rust
#[test]
fn a_declaration_without_a_language_warns() {
    let body = "#file(\"main.py\", ```\nprint(1)\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stderr(&output).contains("chunk ⟪main.py⟫ is declared without a language"),
        "{}",
        stderr(&output)
    );
}
````)

#chunk("flow: an_empty_chunk_is_an_error", ````rust
#[test]
fn an_empty_chunk_is_an_error() {
    let body = "#file(\"main.py\", ```py\n```)\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(stderr(&output).contains("is empty"), "{}", stderr(&output));
}
````)

#chunk("flow: a_file_declaration_can_name_a_nested_path", ````rust
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
````)

#chunk("flow: unsafe_paths_are_rejected", ````rust
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
````)

#chunk("flow: map_names_the_chunk_a_generated_line_came_from", ````rust
#[test]
fn map_names_the_chunk_a_generated_line_came_from() {
    let (_guard, dir, _) = project(DOC);
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
    assert!(
        stderr(&output).contains("chunk ⟪body⟫, line 2 of it"),
        "{}",
        stderr(&output)
    );

    let reverse = lp(&dir, &["map", "--typ", "body", "--out", "out"]);
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
````)

#chunk("flow: the_demo_tangles_and_runs", ````rust
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

    let tangled = lp(
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

    let checked = lp(
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
````)

#chunk("flow: tangle_speaks_json_about_what_it_wrote", ````rust
#[test]
fn tangle_speaks_json_about_what_it_wrote() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(dir.path().join("README.md"), "the book\n").expect("readme");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", extra-book-files: (\"demo.typ\", \"README.md\")))\n\n#file(\"main.py\", ```py\nprint(1)\n```)\n",
        ),
    )
    .expect("doc");

    let written = lp(dir.path(), &["tangle", "demo.typ"]);
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

    let settled = lp(dir.path(), &["tangle", "demo.typ"]);
    let json: serde_json::Value =
        serde_json::from_str(&stdout(&settled)).expect("one document, and nothing else on stdout");
    assert_eq!(json["changed"], serde_json::json!([]));
    assert_eq!(json["unchanged"][0]["root"], "main.py");
}
````)

#chunk("flow: plan_says_what_a_pass_would_do", ````rust
#[test]
fn plan_says_what_a_pass_would_do() {
    let (_guard, dir, _) = project(DOC);

    let fresh = lp(&dir, &["plan", "demo.typ", "--out", "out"]);
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
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    let settled = lp(&dir, &["plan", "demo.typ", "--out", "out"]);
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
    let drifted = lp(&dir, &["plan", "demo.typ", "--out", "out"]);
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
    let reported = lp(&dir, &["plan", "demo.typ", "--out", "out"]);
    assert!(reported.status.success(), "{}", stderr(&reported));
    let json: serde_json::Value = serde_json::from_str(&stdout(&reported)).expect("one document");
    assert_eq!(json["version"], 1);
    assert_eq!(json["command"], "plan");
    assert_eq!(json["unaccounted"][0]["entries"][0], "leftover.py");
}
````)

#chunk("flow: map_takes_one_direction", ````rust
#[test]
fn map_takes_one_direction() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let nothing = lp(&dir, &["map", "--out", "out"]);
    assert_eq!(nothing.status.code(), Some(2), "{}", stderr(&nothing));
    assert!(stderr(&nothing).contains("--typ"), "{}", stderr(&nothing));

    let line_beside_a_chunk = lp(
        &dir,
        &["map", "--typ", "body", "--line", "3", "--out", "out"],
    );
    assert_eq!(
        line_beside_a_chunk.status.code(),
        Some(2),
        "{}",
        stderr(&line_beside_a_chunk)
    );

    let pair = lp(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(pair.status.success(), "{}", stderr(&pair));
}
````)

#chunk("flow: the_reading_commands_speak_json", ````rust
#[test]
fn the_reading_commands_speak_json() {
    let (_guard, dir, _) = project(DOC);
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let listed = lp(&dir, &["list", "demo.typ"]);
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

    let carried = lp(&dir, &["metadata", "demo.typ"]);
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

    let forward = lp(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(forward.status.success(), "{}", stderr(&forward));
    let mapped: serde_json::Value = serde_json::from_str(&stdout(&forward)).expect("one document");
    assert_eq!(mapped["command"], "map");
    assert_eq!(mapped["file"], "main.py");
    assert_eq!(mapped["chunk"], "body");
    assert_eq!(mapped["exact"], true);

    let past_the_end = lp(
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

    let reverse = lp(&dir, &["map", "--typ", "body", "--out", "out"]);
    assert!(reverse.status.success(), "{}", stderr(&reverse));
    let hits: serde_json::Value = serde_json::from_str(&stdout(&reverse)).expect("one document");
    assert_eq!(hits["hits"][0]["file"], "main.py");
    assert_eq!(hits["hits"][0]["line"], 2);
}
````)

#chunk("flow: a_closed_pipe_is_not_a_panic", ````rust
#[test]
fn a_closed_pipe_is_not_a_panic() {
    let declared: String = (0..2000)
        .map(|i| format!("#chunk(\"c{i}\", ```py\nprint({i})\n```)\n"))
        .collect();
    let many = format!("#file(\"main.py\", ```py\nprint(0)\n```)\n{declared}");
    let (_guard, dir, _) = project(&many);

    let mut child = Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(["list", "demo.typ"])
        .current_dir(&dir)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("run lp");
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
````)

#chunk("flow: explain_rewrites_diagnostics_to_the_chunk", ````rust
#[test]
fn explain_rewrites_diagnostics_to_the_chunk() {
    let (_guard, dir, _) = project(DOC);
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
    let message = stdout(&output);
    assert!(message.contains("chunk ⟪body⟫, line 2 of it"), "{message}");
}
````)

#chunk("flow: weave_renders_a_document_that_imports_the_package", ````rust
#[test]
fn weave_renders_a_document_that_imports_the_package() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("doc.typ"),
        "#import \"lp.typ\": show-rule\n#show: show-rule\n= Woven\n",
    )
    .expect("doc");

    let output = lp(dir.path(), &["weave", "doc.typ", "doc.pdf"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        dir.path().join("doc.pdf").exists(),
        "no document was written"
    );
}
````)

#chunk("flow: the_book_comes_back_out_whole", ````rust
#[test]
fn the_book_comes_back_out_whole() {
    let dir = TempDir::new().expect("temp dir");
    let output = lp(dir.path(), &["self", "book", "--out", "unpacked"]);
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
````)

#chunk("flow: reading_weaves_what_the_binary_carries", ````rust
#[test]
fn reading_weaves_what_the_binary_carries() {
    let dir = TempDir::new().expect("temp dir");
    let output = lp(dir.path(), &["self", "read", "--format", "html"]);
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
````)

#chunk("flow: a_blank_line_in_an_indented_fragment_stays_blank", ````rust
#[test]
fn a_blank_line_in_an_indented_fragment_stays_blank() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#file(\"src/main.rs\", ```rust\nfn outer() {\n    <<inner>>\n}\n```)\n\n#chunk(\"inner\", ```rust\nlet a = 1;\n\nlet b = 2;\n```)\n",
        ),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
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
````)

#chunk("flow: tangling_leaves_only_dot_lp_beside_the_document", ````rust
#[test]
fn tangling_leaves_only_dot_lp_beside_the_document() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document("#file(\"main.py\", ```py\nprint('x')\n```)\n"),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));

    let mut unexpected: Vec<String> = std::fs::read_dir(dir.path())
        .expect("the source directory")
        .flatten()
        .map(|entry| entry.file_name().to_string_lossy().to_string())
        .filter(|name| !["lp.typ", "demo.typ", "tangled", ".lp"].contains(&name.as_str()))
        .collect();
    unexpected.sort();
    assert!(unexpected.is_empty(), "the tool left {unexpected:?} behind");
}
````)

#chunk("flow: a_pdf_gives_the_book_back", ````rust
#[test]
fn a_pdf_gives_the_book_back() {
    let dir = TempDir::new().expect("temp dir");
    let document = Path::new(env!("CARGO_MANIFEST_DIR")).join("book/lp.typ");
    let woven = lp(
        dir.path(),
        &["weave", document.to_str().expect("path"), "page.pdf"],
    );
    assert!(woven.status.success(), "{}", stderr(&woven));

    let taken = lp(
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
````)

#chunk("flow: weaving_a_document_with_no_book_carries_none", ````rust
#[test]
fn weaving_a_document_with_no_book_carries_none() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("plain.typ"), "= Plain\n\nJust words.\n").expect("doc");

    let woven = lp(
        dir.path(),
        &["weave", "plain.typ", "plain.html", "--features", "html"],
    );
    assert!(woven.status.success(), "{}", stderr(&woven));
    let page = std::fs::read_to_string(dir.path().join("plain.html")).expect("page");
    assert!(
        !page.contains("lp-source"),
        "a document with no book got one"
    );
}
````)

#chunk("flow: a_page_gives_the_book_back", ````rust
#[test]
fn a_page_gives_the_book_back() {
    let dir = TempDir::new().expect("temp dir");
    let document = Path::new(env!("CARGO_MANIFEST_DIR")).join("book/lp.typ");
    let woven = lp(
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

    let taken = lp(
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
````)

#chunk("flow: the_book_is_carried_into_the_tree", ````rust
#[test]
fn the_book_is_carried_into_the_tree() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(dir.path().join("README.md"), "the book\n").expect("readme");
    std::fs::create_dir(dir.path().join("chapters")).expect("dir");
    std::fs::write(dir.path().join("chapters/one.typ"), "= One\n").expect("chapter");
    std::fs::write(dir.path().join("ignored.txt"), "not part of it\n").expect("ignored");
    std::fs::write(dir.path().join(".gitignore"), "ignored.txt\n").expect("gitignore");
    std::fs::create_dir_all(dir.path().join(".lp/local/lp/0.1.0")).expect("dir");
    std::fs::write(
        dir.path().join(".lp/local/lp/0.1.0/lib.typ"),
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

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
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
        !dir.path().join("tangled/book/.lp").exists(),
        "and neither is the state the tool keeps for itself"
    );
}
````)

#chunk("flow: an_unknown_tangle_option_is_refused", ````rust
#[test]
fn an_unknown_tangle_option_is_refused() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", nonsense: 1))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(!output.status.success(), "an unknown key is not ignored");
    assert!(
        stderr(&output).contains("unknown tangle option"),
        "the package refuses it where it was written: {}",
        stderr(&output)
    );
}
````)

#chunk("flow: a_moved_book_copy_leaves_no_empty_directory", ````rust
#[test]
fn a_moved_book_copy_leaves_no_empty_directory() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::create_dir_all(dir.path().join("one")).expect("dir");
    std::fs::write(dir.path().join("one/x.txt"), "the book\n").expect("chapter");
    let source = |listed: &str| {
        format!(
            "#tangle-options((book-directory: \"book\", extra-book-files: (\"demo.typ\", \"{listed}\")))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n"
        )
    };
    std::fs::write(dir.path().join("demo.typ"), document(&source("one/x.txt"))).expect("doc");
    let first = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(first.status.success(), "{}", stderr(&first));
    assert!(dir.path().join("tangled/book/one/x.txt").exists());

    std::fs::create_dir_all(dir.path().join("two")).expect("dir");
    std::fs::write(dir.path().join("two/x.txt"), "the book\n").expect("chapter");
    std::fs::write(dir.path().join("demo.typ"), document(&source("two/x.txt"))).expect("doc");
    let moved = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(moved.status.success(), "{}", stderr(&moved));

    assert!(dir.path().join("tangled/book/two/x.txt").exists());
    assert!(
        !dir.path().join("tangled/book/one").exists(),
        "the directory the copy moved out of is gone, not left empty"
    );
}
````)

#chunk("flow: a_stale_book_copy_is_removed_and_check_refuses_it", ````rust
#[test]
fn a_stale_book_copy_is_removed_and_check_refuses_it() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(dir.path().join("README.md"), "the pointer\n").expect("book file");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", extra-book-files: (\"demo.typ\", \"README.md\")))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");
    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(output.status.success(), "{}", stderr(&output));

    let stale = dir.path().join("tangled/book/old.txt");
    std::fs::write(&stale, "from a generation ago\n").expect("stale");
    let checked = lp(dir.path(), &["tangle", "demo.typ", "--check"]);
    assert!(
        !checked.status.success(),
        "check refuses a tree with a stale copy"
    );
    assert!(
        stderr(&checked).contains("no longer names"),
        "and says why: {}",
        stderr(&checked)
    );

    let again = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(again.status.success(), "{}", stderr(&again));
    assert!(
        !stale.exists(),
        "a plain tangle removes what the list stopped naming"
    );
}
````)

#chunk("flow: a_book_name_may_not_leave_the_tree", ````rust
#[test]
fn a_book_name_may_not_leave_the_tree() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((book-directory: \"book\", extra-book-files: (\"../outside.txt\",)))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
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
````)

#chunk("flow: a_book_without_a_directory_is_an_error", ````rust
#[test]
fn a_book_without_a_directory_is_an_error() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.path().join("demo.typ"),
        document(
            "#tangle-options((extra-book-files: (\"main.py\",)))\n\n#file(\"main.py\", ```py\nprint('x')\n```)\n",
        ),
    )
    .expect("doc");

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("book-directory"),
        "the tool says which key is missing: {}",
        stderr(&output)
    );
}
````)

#chunk("flow: a_book_may_not_overwrite_an_output", ````rust
#[test]
fn a_book_may_not_overwrite_an_output() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
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

    let output = lp(dir.path(), &["tangle", "demo.typ"]);
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
````)

#chunk("flow: list_reports_declarations", ````rust
#[test]
fn list_reports_declarations() {
    let (_guard, dir, _) = project(DOC);
    let output = lp(&dir, &["list", "demo.typ"]);
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
````)

#chunk("flow: a_chunk_built_by_code_is_attributed_to_itself", ````rust
#[test]
fn a_chunk_built_by_code_is_attributed_to_itself() {
    let body = "#for i in range(2) [\n  #file(\"gen-\" + str(i) + \".py\", ```py\n  print(#i)\n  ```)\n]\n";
    let (_guard, dir, _) = project(body);
    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(dir.join("out/gen-0.py").exists());
    assert!(dir.join("out/gen-1.py").exists());

    let mapped = lp(
        &dir,
        &["map", "--file", "gen-0.py", "--line", "1", "--out", "out"],
    );
    assert!(
        stderr(&mapped).contains("chunk ⟪gen-0.py⟫, line 1 of it"),
        "{}",
        stderr(&mapped)
    );
}
````)

#chunk("flow: the_declaration_is_where_the_line_lives", ````rust
#[test]
fn the_declaration_is_where_the_line_lives() {
    let (_guard, _dir, text) = project(DOC);
    assert!(line_of(&text, "#chunk(\"imports\"") > 0);
    assert!(line_of(&text, "print('two')") > 0);
}
````)

Two consequences of that rule are worth a test each, because both are the kind that
only shows up in a book that has already travelled: the chapter a document starts
including, and the file it should never have reached for.

#chunk("flow: a_chapter_a_document_includes_travels_with_it", ````rust
#[test]
fn a_chapter_a_document_includes_travels_with_it() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("lp.typ"), PKG).expect("package");
    std::fs::write(dir.path().join("one.typ"), "= One\n").expect("chapter");
    let body = "#import \"lp.typ\": chunk, file, tangle-options\n#tangle-options((book-directory: \"book\"))\n#include \"one.typ\"\n#file(\"main.py\", ```py\nprint(1)\n```)\n";
    std::fs::write(dir.path().join("demo.typ"), body).expect("doc");

    let first = lp(dir.path(), &["tangle", "demo.typ"]);
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
    let second = lp(dir.path(), &["tangle", "demo.typ"]);
    assert!(second.status.success(), "{}", stderr(&second));
    assert!(
        dir.path().join("tangled/book/two.typ").exists(),
        "a chapter the document started including travels on its own"
    );
}
````)

#chunk("flow: a_document_that_reads_outside_itself_cannot_be_carried", ````rust
#[test]
fn a_document_that_reads_outside_itself_cannot_be_carried() {
    let parent = TempDir::new().expect("temp dir");
    let dir = parent.path().join("inside");
    std::fs::create_dir_all(&dir).expect("dir");
    std::fs::write(parent.path().join("outside.typ"), "= Outside\n").expect("chapter");
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    std::fs::write(
        dir.join("demo.typ"),
        "#import \"lp.typ\": chunk, file, tangle-options\n#tangle-options((book-directory: \"book\"))\n#include \"../outside.typ\"\n#file(\"main.py\", ```py\nprint(1)\n```)\n",
    )
    .expect("doc");

    let output = lp(&dir, &["tangle", "demo.typ"]);
    assert!(
        !output.status.success(),
        "a book cannot leave its directory"
    );
    let message = stderr(&output);
    assert!(message.contains("outside.typ"), "{message}");
}
````)
