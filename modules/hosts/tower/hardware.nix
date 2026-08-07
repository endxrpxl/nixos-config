{ ... }:
{
  # Hardware in two halves. `_hardware-generated.nix` is machine truth, written
  # by `nix run .#regen-hardware` on the machine itself and never edited by
  # hand; this wrapper holds everything a human decided. Rescanning hardware
  # therefore overwrites exactly one file, leaves the decisions alone, and
  # arrives as a reviewable diff — rather than reading /etc/nixos impurely at
  # eval time, which would put the host outside the verification surface.
  flake.nixosModules.towerHardware = {
    imports = [
      ./_hardware-generated.nix
    ];
  };
}
