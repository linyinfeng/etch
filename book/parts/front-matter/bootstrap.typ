= Bootstrap

A reader can start from this document alone. Everything here assumes `nix` with flakes and a terminal: Rust and
Typst come from the flake, and nothing else has to be installed.

The first step is the one thing the document cannot produce for itself: a binary that can read it, and this
rendering carries everything that step needs: its own source, and its fragments. No repository, no seed — the
road below takes the step from the document alone. A seed is the other job: it is what the pipeline reads to
keep this repository maintained, generation after generation, and *This repository, and its seed* is where that
is told.

```sh
mkdir -p tangled/book
nix shell nixpkgs#poppler-utils -c pdfdetach -saveall -o tangled/book etch.pdf
```

The page carries the same files in the `etch-source` block it was weaved with, so a reader holding the page
rather than the PDF takes them out of that instead:

```sh
nix shell nixpkgs#python3 -c python3 - <<'EOF'
import json, pathlib, re
page = pathlib.Path("etch.html").read_text()
block = re.search(r'<script type="application/json" id="etch-source"[^>]*>(.*?)</script>', page, re.S)
for path, text in json.loads(block.group(1))["files"].items():
    out = pathlib.Path("tangled/book", path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text)
EOF
```

That is the book itself, file for file, because the rendering carries it. The tree is the rest, and the
rendering does not carry it as a file: it carries the fragments, each captioned with the path it is written to,
so the tree can be read back out of the same document by hand or by a script. Every file declaration is a
root; expand the `<<...>>` references between them, give each one its newline, and write it where its name
says. That is exactly the expansion `etch tangle` performs, and it can be done by hand. No clone and no
branch are involved: the seed belongs to the pipeline, and *This repository, and its seed* is where that is
told. With a tree on disk, build it:

```sh
nix shell nixpkgs#typst nixpkgs#cargo nixpkgs#stdenv.cc -c cargo build --manifest-path tangled/Cargo.toml
```

That binary is the one the rest of this book runs on; *The loop* is what to do with it.
