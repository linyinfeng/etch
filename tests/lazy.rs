//! The lazy contract: a pass touches only what actually changed, refuses to
//! tangle a document that does not evaluate, and keeps the line map usable in
//! both directions.

use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../lit/lp.typ");

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

fn write_doc(dir: &Path, name: &str, body: &str) {
    std::fs::write(dir.join("lp.typ"), PKG).expect("package");
    let text = format!("#import \"lp.typ\": chunk, file, rule\n#show: rule\n{body}");
    std::fs::write(dir.join(name), text).expect("doc");
}

fn project() -> (TempDir, std::path::PathBuf) {
    let dir = TempDir::new().expect("temp dir");
    write_doc(dir.path(), "demo.typ", DOC);
    write_doc(
        dir.path(),
        "second.typ",
        "#file(\"other.py\", ```py\nprint('second')\n```)\n",
    );
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

    write_doc(
        dir.as_path(),
        "demo.typ",
        &DOC.replace("print('two')", "print('three')"),
    );

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

    // Mid-edit, the document does not evaluate: nothing is tangled and the last
    // good output stays where it is.
    write_doc(
        dir.as_path(),
        "demo.typ",
        &DOC.replace("#file(\"main.py\", ```py", "#file(\"main.py\", `"),
    );

    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(
        !output.status.success(),
        "a document that does not evaluate must not be tangled"
    );
    let message = stderr(&output);
    assert!(message.contains("did not evaluate"), "{message}");
    assert_eq!(
        std::fs::read_to_string(dir.join("out/main.py")).expect("main"),
        good
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

    // Forward: which chunk produced this generated line?
    let forward = lp(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(forward.status.success(), "{}", stderr(&forward));
    assert!(
        stdout(&forward).starts_with("chunk ⟪body⟫, line 2 of it"),
        "{}",
        stdout(&forward)
    );

    // Reverse: which generated lines came from that chunk?
    let reverse = lp(&dir, &["map", "--typ", "body", "--out", "out"]);
    assert!(reverse.status.success(), "{}", stderr(&reverse));
    assert!(
        stdout(&reverse).contains("main.py:3"),
        "{}",
        stdout(&reverse)
    );
}

#[test]
fn unused_fragment_warns_without_failing() {
    let (_guard, dir) = project();
    write_doc(
        dir.as_path(),
        "demo.typ",
        &format!("{DOC}\n#chunk(\"never-used\", ```py\nprint('dead')\n```)\n"),
    );

    let output = lp(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stderr(&output).contains("chunk ⟪never-used⟫ is never referenced"),
        "{}",
        stderr(&output)
    );
}
