#import "../../package/lib.typ": chunk, file

= tests/owned.rs — who owns the output directory

Ownership is the part of the tool that can destroy a user's work if it is wrong, so it has the
most cases per line of code: what is accounted for, what is not, which ignore rules count, and
what `--check` and `--delete` each do.

#file("tests/owned.rs", ````rust
<<owned: the fixtures and helpers>>

<<owned: a_dropped_declaration_is_an_error_until_it_is_resolved>>

<<owned: a_refused_pass_writes_nothing>>

<<owned: declared_files_are_accounted_for>>

<<owned: the_pattern_language_is_gitignores>>

<<owned: a_deeper_ignore_file_can_take_a_file_back>>

<<owned: the_pass_keeps_its_own_output_and_any_other_dotfile_is_a_stray>>

<<owned: a_git_directory_is_ordinary_content>>

<<owned: check_reports_a_stray_without_removing_it>>

<<owned: the_stray_report_speaks_json>>

<<owned: deleting_a_foreign_subtree_takes_one_line_and_one_command>>

<<owned: without_a_declaration_a_stray_is_still_an_error>>

<<owned: a_missing_output_directory_is_not_an_io_error>>
<<owned: the_unpacked_package_is_not_content>>
````)

The cases, in the order they appear:

- `a_dropped_declaration_is_an_error_until_it_is_resolved` — deleting a root strands its file as an unaccounted error, with `--delete` as the way out
- `a_refused_pass_writes_nothing` — a pass that refuses a stray has not written a byte of the document s content
- `declared_files_are_accounted_for` — files and directories listed in `.lpignore` are left alone
- `the_pattern_language_is_gitignores` — `build/` and `**/*.log` behave exactly as they do in git
- `a_deeper_ignore_file_can_take_a_file_back` — a nested ignore file decides for its own directory, deepest winning
- `the_pass_keeps_its_own_output_and_any_other_dotfile_is_a_stray` — the map is the tool's own output and the ignore file protects itself, but every other dotfile is
- `a_git_directory_is_ordinary_content` — `.git/` is not special-cased, so it has to be declared like anything else
- `check_reports_a_stray_without_removing_it` — `--check` lists a stray and changes nothing
- `the_stray_report_speaks_json` — `unaccounted` names the directory and the entries, keeps its status, and `--delete` reports what it removed
- `deleting_a_foreign_subtree_takes_one_line_and_one_command` — one compressed entry, one `--delete`, and a subtree is gone
- `without_a_declaration_a_stray_is_still_an_error` — with no `.lpignore` at all, strays are still errors
- `a_missing_output_directory_is_not_an_io_error` — a missing output file is drift, not an I/O failure
- `the_unpacked_package_is_not_content` — the directory the tool unpacks its package into is never reported

#chunk("owned: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../package/lib.typ");

const DOC: &str = "\
= Demo

#file(\"a.py\", ```py
print('a')
```)

#file(\"src/b.py\", ```py
print('b')
```)
";

const IGNORES: &str = "\
# files lp must not touch
handwritten.txt
build/
*.lock
# and the rules themselves: a hand-written ignore file is a file like any other, and a report that
# never saw it is how one survived the declaration that produced it. A document says this by
# declaring the file instead, which is what this repository's does.
.lpignore
";

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

fn write_doc(dir: &Path, name: &str, body: &str) -> String {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    let text = format!(
        "#import \"lp.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule\n{body}"
    );
    std::fs::write(dir.join(name), &text).expect("doc");
    text
}

fn tangled(declaration: &str, extra: &[(&str, &str)]) -> (TempDir, std::path::PathBuf) {
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "doc.typ", DOC);
    if !declaration.is_empty() {
        std::fs::create_dir_all(dir.path().join("out")).expect("out");
        let declaration = format!("{declaration}\n.lpignore\n");
        std::fs::write(dir.path().join("out/.lpignore"), declaration).expect("ignore file");
    }
    for (relative, contents) in extra {
        let path = dir.path().join("out").join(relative);
        std::fs::create_dir_all(path.parent().expect("parent")).expect("dir");
        std::fs::write(&path, contents).expect("file");
    }
    let path = dir.path().to_path_buf();
    let output = lp(&path, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    (dir, path)
}

fn without_b() -> String {
    DOC.replace("\n#file(\"src/b.py\", ```py\nprint('b')\n```)\n", "")
}
````)

#chunk("owned: a_dropped_declaration_is_an_error_until_it_is_resolved", ````rust
#[test]
fn a_dropped_declaration_is_an_error_until_it_is_resolved() {
    let (_guard, dir) = tangled(IGNORES, &[("handwritten.txt", "kept")]);
    write_doc(&dir, "doc.typ", &without_b());
    assert!(dir.join("out/src/b.py").exists());

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success());
    let message = stderr(&output);
    assert!(message.contains("nothing accounts for"), "{message}");
    assert!(message.contains("src/b.py"), "{message}");
    assert!(
        message.contains("lp unaccounted --delete"),
        "the remedy belongs there: {message}"
    );
    assert!(
        dir.join("out/src/b.py").exists(),
        "nothing is removed for you"
    );

    let report = lp(&dir, &["unaccounted", "doc.typ", "--out", "out"]);
    assert_eq!(report.status.code(), Some(1));
    assert!(stderr(&report).contains("src/b.py"), "{}", stderr(&report));

    let mut declaration = std::fs::read_to_string(dir.join("out/.lpignore")).expect("ignore");
    declaration.push_str("src/b.py\n");
    std::fs::write(dir.join("out/.lpignore"), &declaration).expect("ignore");
    let declared = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(declared.status.success(), "{}", stderr(&declared));
    assert!(dir.join("out/src/b.py").exists(), "declared, so kept");

    std::fs::write(dir.join("out/.lpignore"), IGNORES).expect("ignore");
    let deleted = lp(
        &dir,
        &["unaccounted", "doc.typ", "--out", "out", "--delete"],
    );
    assert!(deleted.status.success(), "{}", stderr(&deleted));
    assert!(
        stderr(&deleted).contains("deleted src/b.py"),
        "{}",
        stderr(&deleted)
    );
    assert!(!dir.join("out/src/b.py").exists());
    assert!(
        !dir.join("out/src").exists(),
        "the emptied directory goes too"
    );

    let clean = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(clean.status.success(), "{}", stderr(&clean));
    assert!(
        !dir.join("out/src/.lpmap.json").exists(),
        "the stale map is gone"
    );
    assert!(
        lp(&dir, &["tangle", "doc.typ", "--out", "out", "--check"])
            .status
            .success()
    );
}
````)

#chunk("owned: declared_files_are_accounted_for", ````rust
#[test]
fn declared_files_are_accounted_for() {
    let (_guard, dir) = tangled(
        IGNORES,
        &[
            ("handwritten.txt", "kept by hand"),
            ("build/art.txt", "not ours"),
            ("Cargo.lock", "foreign"),
        ],
    );
    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        !stderr(&output).contains("nothing accounts for"),
        "{}",
        stderr(&output)
    );
    for kept in [
        "out/handwritten.txt",
        "out/build/art.txt",
        "out/Cargo.lock",
        "out/.lpignore",
    ] {
        assert!(dir.join(kept).exists(), "{kept} must survive");
    }
}
````)

#chunk("owned: the_pattern_language_is_gitignores", ````rust
#[test]
fn the_pattern_language_is_gitignores() {
    let (_guard, dir) = tangled(
        "build/\n**/*.log\n",
        &[
            ("build/art.txt", "not ours"),
            ("deep/nested/app.log", "log"),
        ],
    );
    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(dir.join("out/build/art.txt").exists(), "directory pattern");
    assert!(dir.join("out/deep/nested/app.log").exists(), "** pattern");
}
````)

#chunk("owned: a_deeper_ignore_file_can_take_a_file_back", ````rust
#[test]
fn a_deeper_ignore_file_can_take_a_file_back() {
    let (_guard, dir) = tangled(
        "src/*\n",
        &[
            ("src/stale.py", "ours after all"),
            ("src/other.py", "protected"),
        ],
    );
    std::fs::write(dir.join("out/src/.lpignore"), "!stale.py\n").expect("ignore");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("src/stale.py"),
        "{}",
        stderr(&output)
    );
    assert!(dir.join("out/src/other.py").exists(), "still protected");
}
````)

#chunk(
  "owned: the_pass_keeps_its_own_output_and_any_other_dotfile_is_a_stray",
  ````rust
  #[test]
  fn the_pass_keeps_its_own_output_and_any_other_dotfile_is_a_stray() {
      let (_guard, dir) = tangled("kept.dot\n", &[("kept.dot", "x")]);
      std::fs::write(dir.join("out/stray.cache"), "not listed").expect("file");

      let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
      assert!(
          !output.status.success(),
          "an unlisted dotfile is a stray like any other"
      );
      assert!(
          stderr(&output).contains("stray.cache"),
          "{}",
          stderr(&output)
      );
      assert!(
          dir.join("out/.lpmap.json").exists(),
          "the map is the tool's own output, so it is accounted for by name"
      );
      assert!(
          dir.join("out/.lpignore").exists(),
          "and the ignore file is accounted for by the rule inside it"
      );
      assert!(dir.join("out/kept.dot").exists(), "listed, so kept");
  }
  ````,
)

#chunk("owned: a_git_directory_is_ordinary_content", ````rust
#[test]
fn a_git_directory_is_ordinary_content() {
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "doc.typ", DOC);
    std::fs::create_dir_all(dir.path().join("out/.git")).expect("out");
    std::fs::write(dir.path().join("out/.lpignore"), IGNORES).expect("ignore");
    std::fs::write(dir.path().join("out/.git/config"), "[core]\n").expect("file");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success(), "not special-cased");
    assert!(
        stderr(&output).contains(".git/config"),
        "{}",
        stderr(&output)
    );

    let (_guard, declared) = tangled(".git/\n", &[(".git/config", "[core]\n")]);
    assert!(declared.join("out/.git/config").exists());
}
````)

#chunk("owned: check_reports_a_stray_without_removing_it", ````rust
#[test]
fn check_reports_a_stray_without_removing_it() {
    let (_guard, dir) = tangled(IGNORES, &[("handwritten.txt", "kept")]);
    std::fs::write(dir.join("out/leftover.py"), "stale").expect("stray");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out", "--check"]);
    assert!(!output.status.success(), "drift");
    assert!(
        stderr(&output).contains("leftover.py"),
        "{}",
        stderr(&output)
    );
    assert!(
        dir.join("out/leftover.py").exists(),
        "--check changes nothing"
    );
}
````)

#chunk(
  "owned: deleting_a_foreign_subtree_takes_one_line_and_one_command",
  ````rust
  #[test]
  fn deleting_a_foreign_subtree_takes_one_line_and_one_command() {
      let (_guard, dir) = tangled(IGNORES, &[("handwritten.txt", "kept")]);
      std::fs::create_dir_all(dir.join("out/vendor/nested")).expect("dir");
      std::fs::write(dir.join("out/vendor/a.txt"), "x").expect("file");
      std::fs::write(dir.join("out/vendor/nested/b.txt"), "x").expect("file");

      let report = lp(&dir, &["unaccounted", "doc.typ", "--out", "out"]);
      assert_eq!(report.status.code(), Some(1));
      assert!(
          stderr(&report).contains("vendor/a.txt"),
          "{}",
          stderr(&report)
      );

      let deleted = lp(
          &dir,
          &["unaccounted", "doc.typ", "--out", "out", "--delete"],
      );
      assert!(deleted.status.success(), "{}", stderr(&deleted));
      assert!(!dir.join("out/vendor").exists());
      assert!(dir.join("out/handwritten.txt").exists());
  }
  ````,
)

#chunk("owned: the_stray_report_speaks_json", ````rust
#[test]
fn the_stray_report_speaks_json() {
    let (_guard, dir) = tangled(IGNORES, &[("handwritten.txt", "kept")]);
    std::fs::write(dir.join("out/leftover.py"), "stale").expect("stray");

    let reported = lp(&dir, &["unaccounted", "doc.typ", "--out", "out"]);
    assert_eq!(reported.status.code(), Some(1), "bad news is not a failure");
    let json: serde_json::Value = serde_json::from_str(&stdout(&reported)).expect("one document");
    assert_eq!(json["version"], 1);
    assert_eq!(json["command"], "unaccounted");
    assert_eq!(json["unaccounted"][0]["dir"], "");
    assert_eq!(json["unaccounted"][0]["entries"][0], "leftover.py");
    assert_eq!(json["deleted"], serde_json::json!([]));
    assert!(
        dir.join("out/leftover.py").exists(),
        "listing changes nothing"
    );

    let removed = lp(
        &dir,
        &["unaccounted", "doc.typ", "--delete", "--out", "out"],
    );
    assert!(removed.status.success(), "{}", stderr(&removed));
    let cleaned: serde_json::Value = serde_json::from_str(&stdout(&removed)).expect("one document");
    assert_eq!(cleaned["deleted"][0], "leftover.py");
    assert!(!dir.join("out/leftover.py").exists(), "it is gone");
}
````)

#chunk("owned: without_a_declaration_a_stray_is_still_an_error", ````rust
#[test]
fn without_a_declaration_a_stray_is_still_an_error() {
    let (_guard, dir) = tangled("", &[]);
    std::fs::write(dir.join("out/stray.txt"), "who put this here").expect("stray");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(stderr(&output).contains("stray.txt"), "{}", stderr(&output));
    assert!(dir.join("out/stray.txt").exists(), "and nothing removes it");
}
````)

#chunk("owned: the_unpacked_package_is_not_content", ````rust
#[test]
fn the_unpacked_package_is_not_content() {
    let (_guard, dir) = tangled("", &[(".lp/local/lp/0.1.0/lib.typ", "the package")]);
    assert!(dir.join("out/.lp/local/lp/0.1.0/lib.typ").exists());
}
````)

#chunk("owned: a_missing_output_directory_is_not_an_io_error", ````rust
#[test]
fn a_missing_output_directory_is_not_an_io_error() {
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "doc.typ", DOC);
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "doc.typ", "--out", "out", "--check"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("STALE  a.py (file missing)"),
        "{}",
        stderr(&output)
    );
    assert!(!path.join("out").exists(), "--check writes nothing at all");
}
````)

A refused pass has to refuse before it writes, and that is not the same as writing and then
apologising: the file the pass would have changed is the one that tells the two apart.

#chunk("owned: a_refused_pass_writes_nothing", ````rust
#[test]
fn a_refused_pass_writes_nothing() {
    let (_guard, dir) = tangled(IGNORES, &[]);
    std::fs::write(dir.join("out/stray.txt"), "nobody's\n").expect("stray");

    write_doc(&dir, "doc.typ", &DOC.replace("print('b')", "print('B')"));
    let refused = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!refused.status.success(), "{}", stderr(&refused));
    assert_eq!(
        std::fs::read_to_string(dir.join("out/src/b.py")).expect("the output"),
        "print('b')\n",
        "a refused pass leaves every file as it was"
    );
}
````)
