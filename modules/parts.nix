{ inputs, ... }: {
  imports = [
    inputs.home-manager.flakeModules.home-manager
  ];

  flake.overlays.default = import ../overlay.nix;

  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];
}
