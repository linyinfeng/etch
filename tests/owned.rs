//! Nothing under the output directory may go unaccounted for.
//!
//! A file is either produced by a chunk, declared in a `.lpignore`, or an error
//! the user resolves — by declaring it, or by deleting it on purpose. `lp` never
//! removes anything on its own, and it never lets a stray file pass silently.

use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const DOC: &str = "\
```py
print('a')
``` <a.py>

```py
print('b')
``` #label(\"src/b.py\")
";

const IGNORES: &str = "\
# files lp must not touch
handwritten.txt
build/
*.lock
";

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

fn without_b(doc: &str) -> String {
    doc.replace("\n```py\nprint('b')\n``` #label(\"src/b.py\")\n", "")
}

/// A project tangled into an output directory with the given declaration.
fn tangled(declaration: &str, extra: &[(&str, &str)]) -> (TempDir, std::path::PathBuf) {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("doc.typ"), DOC).expect("doc");
    if !declaration.is_empty() {
        std::fs::create_dir_all(dir.path().join("out")).expect("out");
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

#[test]
fn a_deleted_root_chunk_is_an_error_until_it_is_resolved() {
    let (_guard, dir) = tangled(IGNORES, &[("handwritten.txt", "kept")]);
    std::fs::write(dir.join("doc.typ"), without_b(DOC)).expect("doc");
    assert!(dir.join("out/src/b.py").exists());

    // The leftover is an error, not something quietly removed.
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

    // The report agrees, and says so with its exit code.
    let report = lp(&dir, &["unaccounted", "doc.typ", "--out", "out"]);
    assert_eq!(report.status.code(), Some(1));
    assert!(stdout(&report).contains("src/b.py"), "{}", stdout(&report));

    // The other remedy: declare it. Then everything is accounted for again.
    let mut declaration = std::fs::read_to_string(dir.join("out/.lpignore")).expect("ignore");
    declaration.push_str("src/b.py\n");
    std::fs::write(dir.join("out/.lpignore"), &declaration).expect("ignore");
    let declared = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(declared.status.success(), "{}", stderr(&declared));
    assert!(dir.join("out/src/b.py").exists(), "declared, so kept");

    // Undeclare it and delete it deliberately: the stale file and its directory
    // and its map all go.
    std::fs::write(dir.join("out/.lpignore"), IGNORES).expect("ignore");
    let deleted = lp(
        &dir,
        &["unaccounted", "doc.typ", "--out", "out", "--delete"],
    );
    assert!(deleted.status.success(), "{}", stderr(&deleted));
    assert!(
        stdout(&deleted).contains("deleted src/b.py"),
        "{}",
        stdout(&deleted)
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
    // A pass with everything accounted for stays quiet about it.
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

    // `src/*` protects the directory; the deeper `!stale.py` makes that one file
    // ours again, so it has to be accounted for.
    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(
        stderr(&output).contains("src/stale.py"),
        "{}",
        stderr(&output)
    );
    assert!(dir.join("out/src/other.py").exists(), "still protected");
}

#[test]
fn control_files_survive_and_other_dotfiles_are_ordinary_files() {
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
        "the ledger is never content"
    );
    assert!(dir.join("out/.lpignore").exists(), "nor are the rules");
    assert!(dir.join("out/kept.dot").exists(), "listed, so kept");
}

#[test]
fn a_git_directory_is_ordinary_content() {
    // Nothing is special-cased, not even a repository: it is kept because the
    // rules say so, not because the tool knows what `.git` is.
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("doc.typ"), DOC).expect("doc");
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

    // The escape hatch is the ignore file, like for anything else.
    let (_guard, declared) = tangled(".git/\n", &[(".git/config", "[core]\n")]);
    assert!(declared.join("out/.git/config").exists());
}

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

#[test]
fn deleting_a_foreign_subtree_takes_one_line_and_one_command() {
    let (_guard, dir) = tangled(IGNORES, &[("handwritten.txt", "kept")]);
    std::fs::create_dir_all(dir.join("out/vendor/nested")).expect("dir");
    std::fs::write(dir.join("out/vendor/a.txt"), "x").expect("file");
    std::fs::write(dir.join("out/vendor/nested/b.txt"), "x").expect("file");

    let report = lp(&dir, &["unaccounted", "doc.typ", "--out", "out"]);
    assert_eq!(report.status.code(), Some(1));
    assert!(
        stdout(&report).contains("vendor/a.txt"),
        "{}",
        stdout(&report)
    );

    let deleted = lp(
        &dir,
        &["unaccounted", "doc.typ", "--out", "out", "--delete"],
    );
    assert!(deleted.status.success(), "{}", stderr(&deleted));
    assert!(!dir.join("out/vendor").exists());
    assert!(dir.join("out/handwritten.txt").exists());
}

#[test]
fn without_a_declaration_a_stray_is_still_an_error() {
    // The output directory is lp's whether or not it declares anything, so a file
    // nothing produces is reported rather than ignored.
    let (_guard, dir) = tangled("", &[]);
    std::fs::write(dir.join("out/stray.txt"), "who put this here").expect("stray");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(!output.status.success());
    assert!(stderr(&output).contains("stray.txt"), "{}", stderr(&output));
    assert!(dir.join("out/stray.txt").exists(), "and nothing removes it");
}

#[test]
fn a_missing_output_directory_is_not_an_io_error() {
    // `lp tangle --check` on a fresh checkout: the outputs are missing, which is
    // drift, and that is what it should say.
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("doc.typ"), DOC).expect("doc");
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
