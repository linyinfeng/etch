{
  description = "literate — Typst-based literate programming for arbitrary target languages";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          # typst: weave + the tangle front end (`typst eval`)
          # python3: the throwaway spike in experiments/, not the product
          packages = with pkgs; [ cargo rustc rustfmt clippy typst python3 ];
        };
      });
    };
}
