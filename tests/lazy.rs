//! The lazy/watch contract: a pass must touch only what actually changed, refuse
//! half-written documents, and keep the line map usable in both directions.

use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const DOC: &str = "\
= Demo

```py
<<imports>>
<<body>>
``` <main.py>

```py
import sys
``` <imports>

```py
print('one')
``` <body>

```py
print('two')
``` <body>
";

const SECOND: &str = "\
```py
print('second')
``` <other.py>
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

fn project() -> (TempDir, std::path::PathBuf) {
    let dir = TempDir::new().expect("temp dir");
    std::fs::write(dir.path().join("demo.typ"), DOC).expect("doc");
    std::fs::write(dir.path().join("second.typ"), SECOND).expect("doc");
    let path = dir.path().to_path_buf();
    (dir, path)
}

fn modified(path: &Path) -> std::time::SystemTime {
    std::fs::metadata(path)
        .expect("metadata")
        .modified()
        .expect("mtime")
}

#[test]
fn a_pass_does_not_touch_files_that_did_not_change() {
    let (_guard, dir) = project();
    let first = lp(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"]);
    assert!(first.status.success(), "{}", stderr(&first));
    assert!(stdout(&first).contains("wrote  main.py"));
    assert!(stdout(&first).contains("wrote  other.py"));

    let before = (
        modified(&dir.join("out/main.py")),
        modified(&dir.join("out/other.py")),
        modified(&dir.join("out/.lpmap.json")),
    );
    std::thread::sleep(std::time::Duration::from_millis(30));

    let second = lp(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"]);
    assert!(second.status.success(), "{}", stderr(&second));
    assert!(
        !stdout(&second).contains("wrote"),
        "nothing should be rewritten: {}",
        stdout(&second)
    );

    let after = (
        modified(&dir.join("out/main.py")),
        modified(&dir.join("out/other.py")),
        modified(&dir.join("out/.lpmap.json")),
    );
    assert_eq!(before, after, "a no-op pass must not touch mtimes");
}

#[test]
fn only_the_affected_output_is_rewritten() {
    let (_guard, dir) = project();
    assert!(
        lp(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"])
            .status
            .success()
    );

    // Edit a fragment that only <main.py> pulls in.
    let doc = DOC.replace("print('two')", "print('three')");
    std::fs::write(dir.join("demo.typ"), &doc).expect("rewrite doc");

    let output = lp(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let report = stdout(&output);
    assert!(report.contains("wrote  main.py"), "{report}");
    assert!(
        !report.contains("wrote  other.py"),
        "the untouched document must not be rewritten: {report}"
    );
    assert!(
        std::fs::read_to_string(dir.join("out/main.py"))
            .expect("main")
            .contains("print('three')")
    );
}

#[test]
fn a_half_written_document_is_not_tangled() {
    let (_guard, dir) = project();
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    let good = std::fs::read_to_string(dir.join("out/main.py")).expect("main");

    // An unclosed label is exactly the mid-edit state that would silently drop a chunk.
    let broken = DOC.replace("``` <main.py>", "``` #label(\"main.py");
    std::fs::write(dir.join("demo.typ"), &broken).expect("rewrite doc");

    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(
        !output.status.success(),
        "a broken document must not be tangled"
    );
    // The document must evaluate before it can say what its chunks are, and the
    // error is Typst's own diagnostic — with the file and the line.
    assert!(
        stderr(&output).contains("did not evaluate") && stderr(&output).contains("unclosed"),
        "{}",
        stderr(&output)
    );
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main"),
        good,
        "the last good output stays"
    );
}

#[test]
fn map_works_in_both_directions() {
    let (_guard, dir) = project();
    assert!(
        lp(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let forward = lp(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(forward.status.success(), "{}", stderr(&forward));
    let forward = stdout(&forward);
    let typ_line = forward
        .lines()
        .next()
        .expect("first line")
        .rsplit(':')
        .next()
        .expect("line")
        .to_string();
    assert!(forward.starts_with("demo.typ:"), "{forward}");

    // Reverse: that .typ line produced exactly line 3 of main.py.
    let reverse = lp(
        &dir,
        &[
            "map", "--typ", "demo.typ", "--line", &typ_line, "--out", "out",
        ],
    );
    assert!(reverse.status.success(), "{}", stderr(&reverse));
    assert!(
        stdout(&reverse).contains("main.py:3"),
        "{}",
        stdout(&reverse)
    );
}

#[test]
fn unused_chunk_warns_without_failing() {
    let (_guard, dir) = project();
    let doc = format!("{DOC}\n```py\nprint('dead')\n``` <never-used>\n");
    std::fs::write(dir.join("demo.typ"), &doc).expect("doc");

    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stderr(&output).contains("chunk <<never-used>> is never referenced"),
        "{}",
        stderr(&output)
    );
}
