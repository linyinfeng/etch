//! Declarative ownership: a `.lpignore` in the output tree says "the files here
//! are lp's, except what this file lists", with gitignore's own rules — so a
//! deleted root chunk cannot leave a stale file behind, while hand-written and
//! foreign files stay put.

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

fn string(doc: &str) -> String {
    doc.to_string()
}

/// A project whose output directory declares ownership of itself.
fn managed(ignore_file: &str, extra: &[(&str, &str)]) -> (TempDir, std::path::PathBuf) {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("doc.typ"), DOC).expect("doc");
    std::fs::create_dir_all(dir.path().join("out")).expect("out");
    std::fs::write(dir.path().join("out/.lpignore"), ignore_file).expect("ignore file");
    for (rel, contents) in extra {
        let path = dir.path().join("out").join(rel);
        std::fs::create_dir_all(path.parent().expect("parent")).expect("dir");
        std::fs::write(&path, contents).expect("file");
    }
    let path = dir.path().to_path_buf();
    let output = lp(&path, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    (dir, path)
}

fn without_b(doc: &str) -> String {
    doc.replace("\n```py\nprint('b')\n``` #label(\"src/b.py\")\n", "")
}

#[test]
fn deleting_a_root_chunk_removes_its_file_and_the_directories_left_behind() {
    let (_guard, dir) = managed(
        IGNORES,
        &[
            ("handwritten.txt", "kept by hand"),
            ("build/art.txt", "not ours"),
            ("Cargo.lock", "foreign lockfile"),
        ],
    );
    assert!(dir.join("out/src/b.py").exists());

    // A leftover the tool has never heard of: inside a managed directory, so it
    // is a candidate too — that is the point of declaring ownership.
    std::fs::write(dir.join("out/previous-version.py"), "stale").expect("stray");
    std::fs::write(dir.join("doc.typ"), without_b(DOC)).expect("doc");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let report = stdout(&output);
    assert!(report.contains("pruned src/b.py"), "{report}");
    assert!(report.contains("pruned previous-version.py"), "{report}");

    assert!(!dir.join("out/src/b.py").exists());
    assert!(
        !dir.join("out/src").exists(),
        "an emptied directory goes too"
    );
    assert!(!dir.join("out/previous-version.py").exists());
    assert!(dir.join("out/a.py").exists());
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
    // `dir/` and `**` work as they do in a `.gitignore`; a match protects the file
    // (here: it is not ours to delete), and everything unprotected that no chunk
    // produces goes.
    let (_guard, dir) = managed(
        "build/\n**/*.log\n",
        &[
            ("build/art.txt", "not ours"),
            ("deep/nested/app.log", "log"),
            ("deep/nested/keep.txt", "ours"),
        ],
    );
    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));

    assert!(dir.join("out/build/art.txt").exists(), "directory pattern");
    assert!(dir.join("out/deep/nested/app.log").exists(), "** pattern");
    assert!(
        !dir.join("out/deep/nested/keep.txt").exists(),
        "unprotected and unproduced: {}",
        stdout(&output)
    );
}

#[test]
fn a_deeper_ignore_file_can_take_a_file_back() {
    // Precedence is gitignore's: the deeper file wins, and `!` removes a file from
    // the protected set (makes it ours again). One walk applies both, so the
    // result does not depend on how many `.lpignore` files there are.
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("doc.typ"), DOC).expect("doc");
    std::fs::create_dir_all(dir.path().join("out/src")).expect("out");
    std::fs::write(dir.path().join("out/.lpignore"), "src/*\n").expect("ignore");
    std::fs::write(dir.path().join("out/src/.lpignore"), "!stale.py\n").expect("ignore");
    std::fs::write(dir.path().join("out/src/stale.py"), "ours after all").expect("file");
    std::fs::write(dir.path().join("out/src/other.py"), "protected").expect("file");
    let path = dir.path().to_path_buf();

    let output = lp(&path, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        !path.join("out/src/stale.py").exists(),
        "taken back by the deeper file: {}",
        stdout(&output)
    );
    assert!(
        path.join("out/src/other.py").exists(),
        "still protected by the outer file"
    );
    assert!(path.join("out/src/b.py").exists(), "produced by a chunk");
}

#[test]
fn control_files_survive_and_other_dotfiles_are_ordinary_files() {
    let (_guard, dir) = managed("kept.dot\n", &[("kept.dot", "x"), ("stray", "y")]);
    std::fs::write(dir.join("out/stray.cache"), "not listed").expect("file");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));

    // The ledger and the rules themselves are never content.
    assert!(dir.join("out/.lpmap.json").exists());
    assert!(dir.join("out/.lpignore").exists());
    // A dotfile is a file: listed, it stays; unlisted, it goes.
    assert!(dir.join("out/kept.dot").exists());
    assert!(!dir.join("out/stray.cache").exists(), "{}", stdout(&output));
}

#[test]
fn a_git_directory_is_ordinary_content() {
    // Nothing is special-cased, not even a repository: if one ends up in the
    // output directory it is kept because the rules say so, not because the tool
    // knows what `.git` is.
    let (_guard, dir) = managed(IGNORES, &[(".git/config", "[core]\n")]);
    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        !dir.join("out/.git/config").exists(),
        "unlisted, so it goes: {}",
        stdout(&output)
    );

    let (_guard, dir) = managed(".git/\n", &[(".git/config", "[core]\n")]);
    assert!(dir.join("out/.git/config").exists(), "listed, so it stays");
}

#[test]
fn without_a_declaration_nothing_is_ever_removed() {
    // No `.lpignore` anywhere: the output directory never said it was ours, so
    // even the file of a deleted chunk stays — and nothing is reported as gone.
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("doc.typ"), DOC).expect("doc");
    let path = dir.path().to_path_buf();
    assert!(
        lp(&path, &["tangle", "doc.typ", "--out", "out"])
            .status
            .success()
    );

    std::fs::write(path.join("out/precious.py"), "by hand").expect("file");
    std::fs::write(path.join("doc.typ"), without_b(DOC)).expect("doc");

    let output = lp(&path, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(!stdout(&output).contains("pruned"), "{}", stdout(&output));
    assert!(path.join("out/precious.py").exists());
    assert!(
        path.join("out/src/b.py").exists(),
        "stale, but never declared ours"
    );
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
    let report = stderr(&output);
    assert!(report.contains("STALE  a.py (file missing)"), "{report}");
    assert!(!path.join("out").exists(), "--check writes nothing at all");
}

#[test]
fn a_map_goes_away_with_the_files_it_explained() {
    let (_guard, dir) = managed(IGNORES, &[]);
    assert!(dir.join("out/src/.lpmap.json").exists());

    std::fs::write(dir.join("doc.typ"), without_b(DOC)).expect("doc");
    assert!(
        lp(&dir, &["tangle", "doc.typ", "--out", "out"])
            .status
            .success()
    );

    assert!(
        !dir.join("out/src/.lpmap.json").exists(),
        "the map travelled with src/"
    );
    assert!(!dir.join("out/src").exists(), "and so did the directory");
    assert!(
        dir.join("out/.lpmap.json").exists(),
        "the root map stays: a.py is still there"
    );
}

#[test]
fn files_nothing_accounts_for_are_named() {
    // Where no declaration owns the directory nothing is removed, so a file that
    // neither a chunk nor an ignore file explains is invisible — unless it is
    // named. That is the case the report exists for.
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("doc.typ"), DOC).expect("doc");
    let path = dir.path().to_path_buf();
    assert!(
        lp(&path, &["tangle", "doc.typ", "--out", "out"])
            .status
            .success()
    );

    std::fs::write(path.join("out/stray.txt"), "who put this here").expect("stray");

    let tangle = lp(&path, &["tangle", "doc.typ", "--out", "out"]);
    assert!(
        stderr(&tangle).contains("nothing accounts for"),
        "the normal flow should mention it: {}",
        stderr(&tangle)
    );

    let output = lp(&path, &["unaccounted", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let report = stdout(&output);
    assert!(report.contains("stray.txt"), "{report}");
    assert!(!report.contains("a.py"), "produced: {report}");
    assert!(
        !report.contains("src/"),
        "a directory holding produced files: {report}"
    );

    // It is a report, not an action: nothing removes files without a declaration.
    assert!(path.join("out/stray.txt").exists());
}

#[test]
fn a_carelessly_owned_directory_still_lets_the_sweep_act() {
    // In a declared directory an undeclared file is the sweep's business, so it
    // is removed rather than reported — that is what declaring the directory
    // means.
    let (_guard, dir) = managed(IGNORES, &[("handwritten.txt", "kept")]);
    std::fs::write(dir.join("out/target-artifact"), "foreign").expect("file");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stdout(&output).contains("pruned target-artifact"),
        "{}",
        stdout(&output)
    );
    assert!(!dir.join("out/target-artifact").exists());
    assert!(
        dir.join("out/handwritten.txt").exists(),
        "declared, so kept"
    );
}

#[test]
fn check_is_a_dry_run_for_the_sweep() {
    let (_guard, dir) = managed(IGNORES, &[]);
    std::fs::write(dir.join("out/leftover.py"), "stale").expect("stray");

    let output = lp(&dir, &["tangle", "doc.typ", "--out", "out", "--check"]);
    assert!(!output.status.success(), "drift must fail the check");
    assert!(
        stderr(&output).contains("ORPHAN leftover.py"),
        "{}",
        stderr(&output)
    );
    assert!(
        dir.join("out/leftover.py").exists(),
        "--check must not delete anything"
    );
}

#[test]
fn nested_managed_directories_keep_their_scoping() {
    // Only `src/` declares ownership, so a stray file next to it is not content
    // of anything and stays put.
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("doc.typ"), string(DOC)).expect("doc");
    std::fs::create_dir_all(dir.path().join("out")).expect("out");
    std::fs::write(dir.path().join("out/.gitignore"), "hand made").expect("outer file");
    std::fs::create_dir_all(dir.path().join("out/src")).expect("dir");
    std::fs::write(dir.path().join("out/src/.lpignore"), "# ours\n").expect("ignore");
    let path = dir.path().to_path_buf();
    assert!(
        lp(&path, &["tangle", "doc.typ", "--out", "out"])
            .status
            .success()
    );

    std::fs::write(path.join("out/src/stale.py"), "stale").expect("stray");
    let output = lp(&path, &["tangle", "doc.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        !path.join("out/src/stale.py").exists(),
        "inside the managed directory"
    );
    assert!(
        path.join("out/.gitignore").exists(),
        "outside it, so not ours"
    );
}
