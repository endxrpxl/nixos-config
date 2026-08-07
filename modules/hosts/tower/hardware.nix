{ ... }:
{
  # Hardware in two halves. `_hardware-generated.nix` is machine truth, written
  # by `nix run .#regen-hardware` on the machine itself and never edited by
  # hand; this wrapper holds everything a human decided. Rescanning hardware
  # therefore overwrites exactly one file and leaves the decisions alone.
  flake.nixosModules.towerHardware = {
    imports = [
      ./_hardware-generated.nix
    ];
  };
}
