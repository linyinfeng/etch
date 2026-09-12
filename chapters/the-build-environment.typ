#import "@local/lp:0.1.0": chunk, file

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

The dependencies are a decision like any other, and the policy (D7) is that a mature crate
beats a hand-written wheel: clap for the command line, ignore for the ignore rules, miette for
the error rendering, notify and its debouncer for the watcher, regex for the diagnostic shapes,
serde for the maps. `tempfile` is the only one the tests need, which is why it is in its own
table.

#chunk("env: what the package is", ````toml
[package]
name = "lp"
version = "0.1.0"
edition = "2024"
publish = false
description = "Typst-based literate programming: tangle source files out of a .typ document"
````)

#chunk("env: the runtime dependencies", ````toml
[dependencies]
include_dir = "0.7"
lopdf = { version = "0.45", default-features = false }
clap = { version = "4", features = ["derive"] }
ignore = "0.4.33"
miette = { version = "7", features = ["fancy"] }
notify = "8.2.0"
notify-debouncer-full = "0.7.0"
regex = "1"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
thiserror = "2"
````)

#chunk("env: what only the tests need", ````toml
[dev-dependencies]
serde_json = "1"
tempfile = "3"
````)
