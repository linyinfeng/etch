{
  description = "etch: literate programming for Typst documents";

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
          inputs.treefmt-nix.flakeModule

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

                etch = craneLib.buildPackage (
                  cargoEnv
                  // {
                    inherit src cargoArtifacts;

                    doCheck = false;

                    nativeBuildInputs = [ pkgs.makeWrapper ];

                    postInstall = ''
                      wrapProgram $out/bin/etch --prefix PATH : ${lib.makeBinPath [ pkgs.typst ]}
                    '';
                  }
                );

                roundtrip =
                  pkgs.runCommand "etch-roundtrip"
                    {
                      nativeBuildInputs = [
                        pkgs.typst
                        etch
                      ];
                    }
                    ''
                      work=$PWD/work
                      mkdir -p "$work"

                      cp -r "${./book}" "$work/carried"
                      cp -r "${./book}" "$work/woven"
                      chmod -R u+w "$work/carried" "$work/woven"

                      pushd "$work/woven" >/dev/null
                      etch weave etch.typ "$work/etch.pdf"
                      etch weave etch.typ "$work/etch.html" --features html
                      popd >/dev/null

                      for format in pdf html; do
                        etch extract --format "$format" "$work/etch.$format" --out "$work/back-$format"
                        diff -r "$work/carried" "$work/back-$format"
                      done
                      touch "$out"
                    '';

                gates = {
                  package = etch;

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
                  inherit etch;
                  default = etch;
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
        ];

        flake.githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
          inherit (config.flake) checks;
        };
      }
    );
}
