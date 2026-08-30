{ inputs, ... }: {
  # Hardware in two halves. `_hardware-generated.nix` is machine truth, written
  # by `nix run .#regen-hardware` on the machine itself and never edited by
  # hand; this wrapper holds everything a human decided. Rescanning hardware
  # therefore overwrites exactly one file and leaves the decisions alone.
  flake.nixosModules.laptopHardware =
    { config, lib, ... }:
    {
      imports = [
        ./_hardware-generated.nix

      # ThinkPad T14 Gen 3, Intel (12th gen). nixos-hardware has no
      # `intel-gen3` module. The Intel line jumps gen1 to gen6, so the
      # generic T14 module (backlight and touchpad quirks, SSD and laptop
      # defaults) is paired with the Intel CPU module, which also brings in
      # the integrated graphics configuration.
      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14
      inputs.nixos-hardware.nixosModules.common-cpu-intel
    ];
      # Swap, for paging under memory pressure. 20 GiB on 16 GiB of RAM is
      # generous for that alone, and costs ~5% of the free space here; it is
      # sized to hold a hibernation image this machine turns out to be unable to
      # write.
      #
      # This sits in the hand-written half rather than in `power` because it is a
      # fact about this machine's RAM and disk, and it has to be read alongside
      # the `swapDevices = [ ]` next door. It cannot move *into* that file:
      # `nixos-generate-config` deliberately skips /proc/swaps entries of type
      # `file`, so a rescan will never emit this. `swapDevices` is a list option,
      # so the two definitions concatenate and a rescan cannot eat this one.
      #
      # Nothing needs creating by hand: `mkswap-swapfile.service` allocates and
      # formats the file on activation if it is absent.
      swapDevices = [
        {
          device = "/swapfile";
          size = 20 * 1024;
        }
      ];
    };
}
