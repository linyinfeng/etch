#import "../../package/lib.typ": chunk, file

= tests/lazy.rs — what a pass touches

The discipline of a pass, with no watcher in the picture: what matters is which bytes it writes and which it
leaves alone. Something else re-runs this command — a person, or a watcher of their choosing — so a pass that
rewrote everything would make every save look like a reason to rebuild. The mtime assertions are the reason the
file exists — cargo wakes on an mtime, not on a diff.

#file("tests/lazy.rs", ````rust
<<lazy: the fixtures and helpers>>

<<lazy: a_pass_does_not_touch_files_that_did_not_change>>

<<lazy: only_the_affected_output_is_rewritten>>

<<lazy: a_half_written_document_is_not_tangled>>

<<lazy: map_works_in_both_directions>>

<<lazy: unused_fragment_warns_without_failing>>
````)

The cases, in the order they appear:

- `a_pass_does_not_touch_files_that_did_not_change` — the first pass writes, the second rewrites nothing at all
- `only_the_affected_output_is_rewritten` — editing one document rewrites only the files that changed
- `a_half_written_document_is_not_tangled` — a document that does not evaluate leaves the previous output in place
- `map_works_in_both_directions` — `etch map` answers forwards and backwards
- `unused_fragment_warns_without_failing` — a fragment nobody references is a warning, not a failure

#chunk("lazy: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::{Command, Output};

use tempfile::TempDir;

const PKG: &str = include_str!("../package/lib.typ");

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
",
);

fn etch(dir: &Path, args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_etch"))
        .args(args)
        .env("ETCH_LOG", "debug")
        .current_dir(dir)
        .output()
        .expect("run etch")
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).to_string()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).to_string()
}

fn write_doc(dir: &Path, name: &str, body: &str) {
    std::fs::write(dir.join("etch.typ"), PKG).expect("package");
    let text = format!(
        "#import \"etch.typ\": chunk, file, tangle-options, show-rule\n#show: show-rule\n{body}"
    );
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
````)

#chunk("lazy: a_pass_does_not_touch_files_that_did_not_change", ````rust
#[test]
fn a_pass_does_not_touch_files_that_did_not_change() {
    let (_guard, dir) = project();
    let first = etch(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"]);
    assert!(first.status.success(), "{}", stderr(&first));
    assert!(stderr(&first).contains("wrote  main.py"));
    assert!(stderr(&first).contains("wrote  other.py"));

    let before = (
        modified(&dir.join("out/main.py")),
        modified(&dir.join("out/other.py")),
        modified(&dir.join("out/.etchmap.json")),
    );
    std::thread::sleep(std::time::Duration::from_millis(30));

    let second = etch(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"]);
    assert!(second.status.success(), "{}", stderr(&second));
    let written: serde_json::Value = serde_json::from_str(&stdout(&second)).expect("one document");
    assert_eq!(
        written["changed"],
        serde_json::json!([]),
        "nothing should be rewritten: {}",
        stdout(&second)
    );

    let after = (
        modified(&dir.join("out/main.py")),
        modified(&dir.join("out/other.py")),
        modified(&dir.join("out/.etchmap.json")),
    );
    assert_eq!(before, after, "a no-op pass must not touch mtimes");
}
````)

#chunk("lazy: only_the_affected_output_is_rewritten", ````rust
#[test]
fn only_the_affected_output_is_rewritten() {
    let (_guard, dir) = project();
    assert!(
        etch(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"])
            .status
            .success()
    );

    write_doc(
        dir.as_path(),
        "demo.typ",
        &DOC.replace("print('two')", "print('three')"),
    );

    let output = etch(&dir, &["tangle", "demo.typ", "second.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    let report = stderr(&output);
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
````)

#chunk("lazy: a_half_written_document_is_not_tangled", ````rust
#[test]
fn a_half_written_document_is_not_tangled() {
    let (_guard, dir) = project();
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );
    let good = std::fs::read_to_string(dir.join("out/main.py")).expect("main");

    write_doc(
        dir.as_path(),
        "demo.typ",
        &DOC.replace("#file(\"main.py\", ```py", "#file(\"main.py\", `"),
    );

    let output = etch(&dir, &["tangle", "demo.typ", "--out", "out"]);
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
````)

#chunk("lazy: map_works_in_both_directions", ````rust
#[test]
fn map_works_in_both_directions() {
    let (_guard, dir) = project();
    assert!(
        etch(&dir, &["tangle", "demo.typ", "--out", "out"])
            .status
            .success()
    );

    let forward = etch(
        &dir,
        &["map", "--file", "main.py", "--line", "3", "--out", "out"],
    );
    assert!(forward.status.success(), "{}", stderr(&forward));
    assert!(
        stderr(&forward).contains("chunk ⟪body⟫, line 2 of it"),
        "{}",
        stderr(&forward)
    );

    let reverse = etch(&dir, &["map", "--typ", "body", "--out", "out"]);
    assert!(reverse.status.success(), "{}", stderr(&reverse));
    assert!(
        stdout(&reverse).contains("\"file\":\"main.py\""),
        "{}",
        stdout(&reverse)
    );
}
````)

#chunk("lazy: unused_fragment_warns_without_failing", ````rust
#[test]
fn unused_fragment_warns_without_failing() {
    let (_guard, dir) = project();
    write_doc(
        dir.as_path(),
        "demo.typ",
        &format!("{DOC}\n#chunk(\"never-used\", ```py\nprint('dead')\n```)\n"),
    );

    let output = etch(&dir, &["tangle", "demo.typ", "--out", "out"]);
    assert!(output.status.success(), "{}", stderr(&output));
    assert!(
        stderr(&output).contains("chunk ⟪never-used⟫ is never referenced"),
        "{}",
        stderr(&output)
    );
}
````)
