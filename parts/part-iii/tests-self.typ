#import "../../package/lib.typ": chunk, file

= tests/self.rs — the invariant that makes self-hosting real

One case, and it is the one that keeps the rest honest: the binary re-tangles this document
into the working tree and insists on finding no difference. Every case above is about some
other document; this one is about this one, and it is what makes editing `src/` by hand
impossible.

#file("tests/self.rs", ````rust
<<self: the fixtures and helpers>>

<<self: the_document_regenerates_the_sources_we_are_running>>
````)

The cases, in the order they appear:

- `the_document_regenerates_the_sources_we_are_running` — the binary reproduces the sources it was built from, byte for byte

#chunk("self: the fixtures and helpers", ````rust
use std::path::Path;
use std::process::Command;
````)

#chunk("self: the_document_regenerates_the_sources_we_are_running", ````rust
#[test]
fn the_document_regenerates_the_sources_we_are_running() {
    let crate_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let map: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(crate_dir.join(".lpmap.json")).expect("the map beside the crate"),
    )
    .expect("the map is json");
    let document = match (
        map["book"]["directory"].as_str(),
        map["docs"]
            .as_array()
            .and_then(|docs| docs.first())
            .and_then(|doc| doc.as_str()),
    ) {
        (Some(book), Some(doc)) => format!("{book}/{doc}"),
        _ => panic!("the map names neither a book nor a document: {map}"),
    };

    let output = Command::new(env!("CARGO_BIN_EXE_lp"))
        .args(["tangle", &document, "--out", ".", "--check"])
        .current_dir(crate_dir)
        .output()
        .expect("run lp");

    assert!(
        output.status.success(),
        "--check reported drift between lp.typ and the sources it generated:\n{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
}
````)
