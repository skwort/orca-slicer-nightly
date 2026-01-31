{
  description = "OrcaSlicer Nightly - tracks the nightly-builds release tag";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      
      nightlyConfig = builtins.fromJSON (builtins.readFile ./nightly.json);
    in {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          orcaslicer-nightly = pkgs.orca-slicer.overrideAttrs (oldAttrs: {
            pname = "orca-slicer-nightly";
            version = nightlyConfig.version;

            src = pkgs.fetchFromGitHub {
              owner = "OrcaSlicer";
              repo = "OrcaSlicer";
              rev = nightlyConfig.rev;
              hash = nightlyConfig.hash;
              fetchSubmodules = true;
            };

            # Nightly may have patches already applied - filter as needed
            patches = builtins.filter (p:
              let name = builtins.baseNameOf (toString p); in
              (pkgs.lib.hasPrefix "0001-not-for-upstream" name)
            ) (oldAttrs.patches or []);

            meta = oldAttrs.meta // {
              description = "OrcaSlicer Nightly (${nightlyConfig.version})";
              mainProgram = "orca-slicer";
            };
          });
        in {
          default = orcaslicer-nightly;
          orca-slicer-nightly = orcaslicer-nightly;
        }
      );

      overlays.default = final: prev: {
        orca-slicer-nightly = self.packages.${prev.system}.default;
      };
    };
}
