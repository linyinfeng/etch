#import "@local/lp:0.1.0": chunk, file

= The program's own pipeline

Everything above is about this repository: one document, its tree, and the seed that makes the first
build possible. The program that comes out is a program, though, and it has a pipeline of its own —
written where it belongs, which is in the program rather than in the repository that produces it.

So these four files are output too. They are declared here, tangled with everything else, and carried
onto the seed branch, which is where they take effect: the branch that holds a generation is the branch
whose copy of a workflow file GitHub reads.

#file("lp.nix", ````nix
<<nix: the package>>
````)

#file("flake.nix", ````nix
<<nix: the flake>>
````)

#file(".github/workflows/check.yml", ````yaml
<<nix: the workflow>>
````)

#file("zizmor.yml", ````yaml
<<nix: the zizmor policy>>
````)

#file("typos.toml", ````toml
<<nix: the words typos should leave alone>>
````)

== The package, the way crane would write it

`crane` builds it, and what that buys is one thing said three ways: the dependency graph is compiled once
and every later step reuses it. A `typst`-sized graph rebuilt for each of lint, test and build would make
the checks below too expensive to keep, which is the same as not having them.

Four things here are this tool's own, and every one of them was found by a failure:

- *Typst is a runtime dependency and a test dependency.* Tangling asks the document for its declarations,
  so both the binary and the tests that tangle have to find `typst` — the wrapper for the first, an input
  for the second. A package that works only when the user happens to have the right thing on their `PATH`
  is not a package.
- *`src` is the whole tree.* Not cargo's idea of a source: `src/metadata.rs` reads the package with
  `include_str!`, `src/embedded.rs` reads the book with `include_dir!`, and
  `the_document_regenerates_the_sources_we_are_running` re-tangles the book against the tree it is running
  in. That last one is why the filtering below is applied to the *dependencies* and not to the crate: the
  test is an assertion about the tree, so the tree has to be the input. It runs in a build of the tree as
  much as in the repository, which is what D15 made true when it rewrote the test to read the map beside
  the crate instead of a path above it.
- *`CARGO_HOME` is moved out of the source.* Crane puts it in `$PWD/.cargo-home`, and the same test asks
  whether the output directory holds anything the document does not account for. A build tool writing into
  the directory under test makes that question unanswerable, so it writes elsewhere. It has to be set from a
  *hook* rather than as a derivation attribute, and that is where a platform constant hides: the first
  version wrote `/build`, which is where Linux puts its temporary build directory and a read-only,
  non-existent one on Darwin. The six matrix entries that had never been built before are what found that —
  on macOS only.
- *The round trip is a check rather than a condition of the build.* Rendering the document and reading the
  book back out of both carriers is a thing to assert, not a thing to make someone pay for by installing
  `lp`.
- *The package does not run the tests.* `doCheck = false` there and a `test` check beside it, because a
  package that ran them as well would fail before a reader could see *which* test broke.

#chunk("nix: the package", ````nix
{ inputs }:
{
  perSystem =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      craneLib = inputs.crane.mkLib pkgs;

      cargoSources = craneLib.fileset.commonCargoSources ./.;

      src = ./.;

      cargoArtifacts = craneLib.buildDepsOnly {
        src = lib.fileset.toSource {
          root = ./.;
          fileset = cargoSources;
        };
      };

      cargoEnv = {
        prePatch = ''export CARGO_HOME="$TMPDIR/cargo-home"'';
      };

      lp = craneLib.buildPackage (
        cargoEnv
        // {
          inherit src cargoArtifacts;

          doCheck = false;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          postInstall = ''
            wrapProgram $out/bin/lp --prefix PATH : ${lib.makeBinPath [ pkgs.typst ]}
          '';
        }
      );

      roundtrip = pkgs.runCommand "lp-roundtrip" { nativeBuildInputs = [ pkgs.typst ]; } ''
        work=$PWD/work
        mkdir -p "$work/src" "$work/run"

        for file in lp.typ README.md .gitignore; do
          cp "${./book}/$file" "$work/src/$file"
          cp "${./book}/$file" "$work/run/$file"
        done

        ( cd "$work/run" && ${lp}/bin/lp weave lp.typ ../lp.pdf && ${lp}/bin/lp weave lp.typ ../lp.html --features html )

        for format in pdf html; do
          ${lp}/bin/lp extract --format "$format" "$work/lp.$format" --out "$work/back-$format"
          diff -r "$work/src" "$work/back-$format"
        done
        touch "$out"
      '';

      gates = {
        package = lp;

        test = craneLib.cargoTest (
          cargoEnv
          // {
            inherit src cargoArtifacts;

            nativeBuildInputs = [ pkgs.typst ];
          }
        );

        clippy = craneLib.cargoClippy (
          cargoEnv
          // {
            inherit src cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          }
        );

        inherit roundtrip;
      };
    in
    {
      packages = {
        inherit lp;
        default = lp;
      };

      checks = gates // {
        devShell = config.devShells.default;
      };

      treefmt = {
        projectRootFile = "flake.nix";

        programs = {
          nixfmt.enable = true;
          taplo.enable = true;
          rustfmt.enable = true;
          typstyle.enable = true;
          mdformat.enable = true;
          jsonfmt.enable = true;

          # Spelling, with a list of words rather than a list of files: see the paragraph above.
          typos = {
            enable = true;
            configFile = "typos.toml";
          };

          yamlfmt = {
            enable = true;
            settings.formatter.retain_line_breaks = true;
          };
          shfmt = {
            enable = true;
            indent_size = 4;
          };

          actionlint.enable = true;
          zizmor.enable = true;
          shellcheck.enable = true;
          deadnix.enable = true;
          statix.enable = true;
        };

        settings.formatter.shfmt.options = [
          "-sr"
          "-kp"
        ];

        settings.formatter.zizmor.options = [
          "--min-severity"
          "high"
        ];
      };

      devShells.default = craneLib.devShell {
        checks = gates;
        packages = [
          config.treefmt.build.wrapper
          pkgs.typst
        ];
      };
    };
}
````)

== The flake, and the systems it is for

Three systems, named once, and `flake-parts` is the skeleton that makes naming them once enough. Five
inputs, and each of them is told to follow ours rather than fetch a copy of nixpkgs of its own; crane
brings no inputs at all, which is how a library that does this much costs one line here. That flatness is
not decoration — a second nixpkgs in the graph is a second `rustc`, and the one place where versions
really matter is the compiler.

The checks are the point of the flake. One per promise, so CI fails on the promise and not on "the build":

- `package` — it builds.
- `test` — it passes its own tests, including the one about the document regenerating this tree.
- `clippy` — it is lint-clean, with warnings denied.
- `treefmt` — every file a formatter has an opinion about is formatted, and the formatters own the
  document's own code as much as the crate's. (No `cargoFmt`: two tools disagreeing about rustfmt's
  options is worse than either one alone.)
- `roundtrip` — the book survives both carriers.
- `devShell` — the shell can be constructed, because a shell that cannot be built is a shell nobody uses.

`nix flake check` builds every one of those for the machine it runs on and evaluates the rest, so a typo in
the Darwin branch of anything is caught on Linux. And because the list *is* an attribute of the flake, the
workflow never repeats it: `githubActions` renders it into a build matrix, which is how the three systems
stop being a claim and become something that ran.

#chunk("nix: the flake", ````nix
{
  description = "lp: literate programming for Typst documents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    crane.url = "github:ipetkov/crane";

    nix-github-actions.url = "github:nix-community/nix-github-actions";
    nix-github-actions.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { config, ... }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];

        imports = [
          (import ./lp.nix { inherit inputs; })
          inputs.treefmt-nix.flakeModule
        ];

        flake.githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
          inherit (config.flake) checks;
        };
      }
    );
}
````)

== The workflow

Three jobs. `matrix` asks the flake which checks exist, so the list of them lives in one place and adding
one is an edit to `lp.nix`. `check` builds each of them on the runner its system calls for — the matrix
knows that `aarch64-linux` means an arm runner and `aarch64-darwin` means a Mac, so the three systems are
three native builds rather than one build and two guesses. It also does not stop at the first failure,
because one failing check should not hide the other seventeen. `prove` runs the other direction: it unpacks
the book the binary carries, tangles it, and runs this tree's own checks in what comes out, which is what
catches a document that no longer reproduces its tree.

The cache is where a pipeline like this earns its keep — a Rust build with Nix is hundreds of derivations,
and the second run should download them instead of building them. The name is the Cachix cache this
repository pushes to; the token comes from a secret, because a signing key in a workflow file is a signing
key given away.

The workflow asks for `contents: read` and nothing more, because neither job writes; it hands the matrix
attribute in through the environment rather than into the shell; it passes `--no-update-lock-file`, because
the lock is part of the book the tree carries and a lock that does not match is drift to fail on rather than
one to quietly resolve; and it keeps a policy file beside it. Each
of those is a finding from the linter, and the linter runs here — in `treefmt`, on every build — rather than
in a script someone remembers to call.

#chunk("nix: the workflow", ````yaml
name: check

permissions:
  contents: read

on:
  push:
    branches: [tangled]
  workflow_dispatch:
  schedule:
    - cron: "0 6 * * *"

jobs:
  matrix:
    runs-on: ubuntu-24.04
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v7
      - uses: cachix/install-nix-action@v31
      - id: set-matrix
        name: ask the flake which checks exist
        run: echo "matrix=$(nix eval --json '.#githubActions.matrix')" >> "$GITHUB_OUTPUT"

  check:
    name: ${{ matrix.name }} (${{ matrix.system }})
    needs: matrix
    strategy:
      fail-fast: false
      matrix: ${{ fromJSON(needs.matrix.outputs.matrix) }}
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v7
      - uses: cachix/install-nix-action@v31
      - uses: cachix/cachix-action@v17
        with:
          name: linyinfeng
          signingKey: ${{ secrets.CACHIX_SIGNING_KEY }}
      - run: nix build -L --no-update-lock-file ".#$ATTR"
        env:
          ATTR: ${{ matrix.attr }}

  prove:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7
      - uses: cachix/install-nix-action@v31
      - uses: cachix/cachix-action@v17
        with:
          name: linyinfeng
          signingKey: ${{ secrets.CACHIX_SIGNING_KEY }}
      - run: nix build -L --no-update-lock-file .#lp
      - run: ./result/bin/lp self prove /tmp/proved
````)

The policy file travels with the tree for the same reason the workflow does: `zizmor` now runs *in* the
build, as one of treefmt's programs, so what it reads has to be part of what the tree is. It is the same
file the local `gates` script points `zizmor` at, which is why it argues for the `@vN` pins only once.

`typos` runs there too, and its configuration is a list of *words* rather than a list of files, which is not
the obvious choice. Excluding a file cannot work here: the words it objects to are `flate` and `writeable`,
both of which appear in the `Cargo.lock` this document quotes verbatim — and a quoted file is not a path any
more, it is the document. A word list is the only mechanism that reaches a word wherever it is written, and
the words are the crate names `flate2` and `writeable`, so the list is short. Note that `typos` flags the
word it matched and not the token: `flate` inside `flate2`, which is why allowing `flate2` would change
nothing.

#chunk("nix: the words typos should leave alone", ````toml
[default.extend-words]
flate = "flate"
writeable = "writeable"
````)

#chunk("nix: the zizmor policy", ````yaml

rules:
  unpinned-uses:
    disable: true
````)
