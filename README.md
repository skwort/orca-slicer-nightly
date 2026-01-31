# orca-slicer-nightly

Always up-to-date Nix package for [OrcaSlicer](https://github.com/OrcaSlicer/OrcaSlicer) nightly builds.

**Automatically updated daily** to track the latest `nightly-builds` tag.

## Why this package?

OrcaSlicer stable releases are infrequent, but development moves fast. I want
the latest OrcaSlicer features, without having to wait for an official release,
and the subsequent nixpkgs update. 

This flake tracks the `nightly-builds` tag, giving you:

1. **Latest Nightly Builds**: New printer profiles, bug fixes, and features as they land
2. **Daily Updates**: GitHub Actions checks for new nightlies every day
3. **Flake-First Design**: Direct flake usage for easy installation

## Quick Start

### Run without installing

```bash
nix run github:skwort/orca-slicer-nightly
```

### Install to your profile

```bash
nix profile install github:skwort/orca-slicer-nightly
```

## Standalone Installation (Without Home Manager)

### Install

```bash
nix profile install github:skwort/orca-slicer-nightly
```

### Verify Installation

```bash
which orca-slicer
orca-slicer --version
```

### Update to Latest Version

```bash
# Update all flake-based packages
nix profile upgrade --all

# Or update only orca-slicer-nightly
nix profile upgrade '.*orca-slicer-nightly.*'
```

### Rollback

```bash
nix profile rollback
```

### Uninstall

```bash
nix profile remove '.*orca-slicer-nightly.*'
```

## Using with Flakes

### In your flake.nix

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    orca-slicer-nightly.url = "github:skwort/orca-slicer-nightly";
  };

  outputs = { self, nixpkgs, orca-slicer-nightly, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [{
        environment.systemPackages = [
          orca-slicer-nightly.packages.x86_64-linux.default
        ];
      }];
    };
  };
}
```

### Using the Overlay

```nix
{
  nixpkgs.overlays = [ orca-slicer-nightly.overlays.default ];
  environment.systemPackages = [ pkgs.orca-slicer-nightly ];
}
```

### With Home Manager

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    orca-slicer-nightly.url = "github:skwort/orca-slicer-nightly";
  };

  outputs = { self, nixpkgs, home-manager, orca-slicer-nightly, ... }: {
    homeConfigurations."username" = home-manager.lib.homeManagerConfiguration {
      modules = [{
        nixpkgs.overlays = [ orca-slicer-nightly.overlays.default ];
        home.packages = [ pkgs.orca-slicer-nightly ];
      }];
    };
  };
}
```

## Development

```bash
# Clone the repository
git clone https://github.com/skwort/orca-slicer-nightly
cd orca-slicer-nightly

# Build the package
nix build

# Run it
nix run

# Check for updates
./scripts/update-version.sh --check

# Run the update
./scripts/update-version.sh
```

## Updating

### Automated Updates

This repository uses GitHub Actions to automatically check for new nightly
builds daily. When a new version is detected:

1. A pull request is automatically created with the version update
2. The source hash is automatically calculated
3. The flake is verified to evaluate correctly

### Manual Updates

```bash
# Check for updates
./scripts/update-version.sh --check

# Update to latest nightly
./scripts/update-version.sh
```

## License

The Nix packaging is MIT licensed. OrcaSlicer itself is licensed under AGPLv3.
