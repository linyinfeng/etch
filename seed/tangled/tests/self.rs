//! Self-reproduction: the document has to regenerate the crate it ships.

use std::path::Path;
use std::process::Command;

/// The document is the source of the files that are compiled, so `--check` in the
/// crate root has to be clean. This is the permanent half of the fixed point:
/// Stage 1 also required the output to equal the frozen seed in `seed/`,
/// which stopped being true the moment the document was refactored (ADR D15).
#[test]
fn the_document_regenerates_the_sources_we_are_running() {
    // The crate lives in `tangled/`, one level below the document it is generated from.
    let root = Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("repository root");
    let output = Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(["tangle", "lp.typ", "--check"])
        .current_dir(root)
        .output()
        .expect("run lp");

    assert!(
        output.status.success(),
        "--check reported drift between lp.typ and the sources it generated:\n{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
}
