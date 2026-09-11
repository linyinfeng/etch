//! Declarative ownership: a `.lpignore` in the output tree says "the files here
//! are lp's, except what this file lists" — so a deleted root chunk cannot leave
//! a stale file behind, while hand-written and foreign files stay put.

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

/// A tangled project whose output directory declares ownership.
fn managed() -> (TempDir, std::path::PathBuf) {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("doc.typ"), DOC).expect("doc");
    std::fs::create_dir_all(dir.path().join("out/build")).expect("out");
    std::fs::write(dir.path().join("out/.lpignore"), IGNORES).expect("ignore file");
    std::fs::write(dir.path().join("out/handwritten.txt"), "kept by hand").expect("handwritten");
    std::fs::write(dir.path().join("out/build/art.txt"), "not ours").expect("artifact");
    std::fs::write(dir.path().join("out/Cargo.lock"), "foreign lockfile").expect("lock");
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
    let (_guard, dir) = managed();
    assert!(dir.join("out/src/b.py").exists());

    // A leftover the tool has never heard of: inside a managed directory, so it
    // is a candidate too (this is the whole point of declaring ownership).
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
}

#[test]
fn ignored_files_survive_every_sweep() {
    let (_guard, dir) = managed();
    std::fs::write(dir.join("doc.typ"), without_b(DOC)).expect("doc");
    assert!(
        lp(&dir, &["tangle", "doc.typ", "--out", "out"])
            .status
            .success()
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
fn without_an_ignore_file_nothing_outside_the_line_map_is_touched() {
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

    let output = lp(&path, &["tangle", "doc.typ", "--out", "out", "--prune"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        !path.join("out/src/b.py").exists(),
        "the map knows this one was ours"
    );
    assert!(
        path.join("out/precious.py").exists(),
        "but not this one: {}",
        stdout(&output)
    );
}

#[test]
fn map_orphans_are_reported_and_need_prune_without_an_ignore_file() {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("doc.typ"), DOC).expect("doc");
    let path = dir.path().to_path_buf();
    assert!(
        lp(&path, &["tangle", "doc.typ", "--out", "out"])
            .status
            .success()
    );
    std::fs::write(path.join("doc.typ"), without_b(DOC)).expect("doc");

    let reported = lp(&path, &["tangle", "doc.typ", "--out", "out"]);
    assert!(reported.status.success(), "{}", stderr(&reported));
    assert!(
        stderr(&reported).contains("orphan src/b.py"),
        "{}",
        stderr(&reported)
    );
    assert!(path.join("out/src/b.py").exists(), "reported, not deleted");

    let pruned = lp(&path, &["tangle", "doc.typ", "--out", "out", "--prune"]);
    assert!(pruned.status.success(), "{}", stderr(&pruned));
    assert!(!path.join("out/src/b.py").exists());
}

#[test]
fn check_is_a_dry_run_for_the_sweep() {
    let (_guard, dir) = managed();
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
fn hidden_files_are_never_removed() {
    let (_guard, dir) = managed();
    std::fs::write(dir.join("out/.gitignore"), "out/").expect("dotfile");
    std::fs::write(dir.join("out/.keep"), "").expect("dotfile");

    assert!(
        lp(&dir, &["tangle", "doc.typ", "--out", "out"])
            .status
            .success()
    );
    assert!(dir.join("out/.gitignore").exists());
    assert!(dir.join("out/.keep").exists());
}
