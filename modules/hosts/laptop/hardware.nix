{ inputs, ... }:
{
  # Hardware in two halves. `_hardware-generated.nix` is machine truth, written
  # by `nix run .#regen-hardware` on the machine itself and never edited by
  # hand; this wrapper holds everything a human decided. Rescanning hardware
  # therefore overwrites exactly one file, leaves the decisions alone, and
  # arrives as a reviewable diff — rather than reading /etc/nixos impurely at
  # eval time, which would put the host outside the verification surface.
  flake.nixosModules.laptopHardware = {
    imports = [
      ./_hardware-generated.nix

      # ThinkPad T14 Gen 3, Intel (12th gen). nixos-hardware has no
      # `intel-gen3` module — the Intel line jumps gen1 to gen6 — so the
      # generic T14 module (backlight and touchpad quirks, SSD and laptop
      # defaults) is paired with the Intel CPU module, which also brings in
      # the integrated graphics configuration.
      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14
      inputs.nixos-hardware.nixosModules.common-cpu-intel
    ];

    # This machine has not been installed yet: the values in
    # `_hardware-generated.nix` are placeholders, not a real scan.
    #
    # `nix flake check` builds this host green regardless — the build never
    # touches a disk — so the check proves this configuration evaluates and
    # builds, and proves nothing at all about whether it boots. See
    # docs/adr/0003-placeholder-host-in-the-verification-surface.md.
    #
    # On arrival, run `nix run .#regen-hardware laptop` on the machine, set
    # `console.keyMap` in configuration.nix to the real layout, confirm
    # `system.stateVersion` matches the release actually installed, and delete
    # this warning.
    warnings = [
      ''
        The `laptop` host is a placeholder: its filesystem UUIDs and console
        keymap are not real values and it will not boot as configured. See
        modules/hosts/laptop/hardware.nix.
      ''
    ];
  };
}
