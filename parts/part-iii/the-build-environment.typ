#import "../../package/lib.typ": chunk, file

= The build environment

The toolchain is a prerequisite rather than an output: without typst there are no declarations to
read, and without cargo there is no binary, but a document cannot ship the tools that read it. So
this chapter is about what the crate *needs* — its name, its dependencies, the versions — and
about the one thing a person has to have before any of it runs.

What that is, concretely: `typst`, and a Rust toolchain complete enough to link — `cargo`, `rustc`
and a C linker. On a machine with a system Rust that is all there is to it; where the tools are not
installed, they can be borrowed for one command:

```sh
nix shell nixpkgs#typst nixpkgs#cargo nixpkgs#stdenv.cc -c cargo test
```

A repository that carried its own environment would need a tracked file the document could not
produce (nix will not evaluate a flake whose files are not in git), so the environment lives
outside this document: it is what the person reading has, not something the document hands over.

#file("Cargo.toml", ````toml
<<env: what the package is>>

<<env: the runtime dependencies>>

<<env: what only the tests need>>
````)

The table's fields before the dependencies say what the crate is and who wrote it: `description` is the sentence the
woven page prints under the title, and `authors` and `repository` are the same two facts for whoever reads the crate
metadadata rather than the page.

The dependencies are a decision like any other, and the policy (D7) is that a mature crate
beats a hand-written wheel: clap for the command line, ignore for the ignore rules, miette for
the error rendering, libc for the one signal this tool resets, regex for the diagnostic shapes,
serde and serde_json for the maps and for the documents on standard output, tracing and
tracing-subscriber for the log, include_dir for the book the binary carries, and lopdf for that
book's carrier in a PDF — the second half of that policy is that every one of them is here for something the
tool could not do well itself, and the log is a level, two writers and a
filter, which is exactly the kind of thing not to write by hand. `tempfile` is the only one the tests need, which is why it is in its own
table.

#chunk("env: what the package is", ````toml
[package]
name = "etch"
version = "0.1.0"
edition = "2024"
publish = false
description = "A literate literate programming program."
authors = ["Lin Yinfeng <lin.yifeng@outlook.com>"]
repository = "https://github.com/linyinfeng/etch"
````)

#chunk("env: the runtime dependencies", ````toml
[dependencies]
include_dir = "0.7"
libc = "0.2"
lopdf = { version = "0.45", default-features = false }
clap = { version = "4", features = ["derive"] }
ignore = "0.4.33"
miette = { version = "7", features = ["fancy"] }
regex = "1"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tracing = "0.1"
tracing-subscriber = { version = "0.3", default-features = false, features = [
  "fmt",
  "ansi",
] }
````)

#chunk("env: what only the tests need", ````toml
[dev-dependencies]
tempfile = "3"
````)
