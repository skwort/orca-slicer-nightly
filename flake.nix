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

            # Keep upstream patches, replacing opencv patch with ours (adds imgcodecs)
            patches = (builtins.filter (p:
              !(pkgs.lib.hasInfix "opencv" (builtins.baseNameOf (toString p)))
            ) (oldAttrs.patches or [])) ++ [
              ./patches/opencv-nix.patch
            ];

            # Nightly's Findlibnoise.cmake expects different variable names
            cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
              "-DLIBNOISE_INCLUDE_DIR=${pkgs.libnoise}/include"
              "-DLIBNOISE_LIBRARY_RELEASE=${pkgs.libnoise}/lib/libnoise-static.a"
            ];

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
