use std::path::Path;
use std::process::Command;

fn book_and_document(crate_dir: &Path) -> (String, String) {
    let map: serde_json::Value = serde_json::from_str(
        &std::fs::read_to_string(crate_dir.join(".etchmap.json"))
            .expect("the map beside the crate"),
    )
    .expect("the map is json");
    match (
        map["book"]["directory"].as_str(),
        map["docs"]
            .as_array()
            .and_then(|docs| docs.first())
            .and_then(|doc| doc.as_str()),
    ) {
        (Some(book), Some(doc)) => (book.to_string(), doc.to_string()),
        _ => panic!("the map names neither a book nor a document: {map}"),
    }
}

#[test]
fn the_document_regenerates_the_sources_we_are_running() {
    let crate_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let (book, doc) = book_and_document(crate_dir);
    let document = format!("{book}/{doc}");

    let output = Command::new(env!("CARGO_BIN_EXE_etch"))
        .args(["tangle", &document, "--out", ".", "--check"])
        .current_dir(crate_dir)
        .output()
        .expect("run etch");

    assert!(
        output.status.success(),
        "--check reported drift between etch.typ and the sources it generated:\n{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
}

#[test]
fn the_package_the_book_carries_is_the_one_the_tree_uses() {
    let crate_dir = Path::new(env!("CARGO_MANIFEST_DIR"));
    let (book, _) = book_and_document(crate_dir);
    let carried =
        std::fs::read(crate_dir.join(&book).join("package/lib.typ")).expect("the book's package");
    let used = std::fs::read(crate_dir.join("package/lib.typ")).expect("the tree's package");

    assert_eq!(
        String::from_utf8_lossy(&carried),
        String::from_utf8_lossy(&used),
        "the document imports one of them and declares the other, and they are one file"
    );
}
