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

    # Swap, for paging under memory pressure. 20 GiB on 16 GiB of RAM is
    # generous for that alone, and costs ~5% of the free space here.
    #
    # It was sized to hold a hibernation image, which this machine turned out
    # to be unable to write — see
    # docs/adr/0006-no-hibernation-while-a-secretmem-user-runs.md. The size is
    # kept because it is already allocated, it is the right size if hibernation
    # ever becomes possible, and there is nothing to reclaim by shrinking it.
    #
    # This sits in the hand-written half rather than in `power` because it is a
    # fact about this machine's RAM and disk, and it has to be read alongside
    # the `swapDevices = [ ]` next door. It cannot move *into* that file:
    # `nixos-generate-config` reads /proc/swaps and deliberately skips entries
    # of type `file`, on the grounds that swap files are declared by hand — so
    # a rescan will never emit this, no matter how the machine is running when
    # it is run. `swapDevices` is a list option, so the two definitions
    # concatenate and a rescan cannot eat this one.
    #
    # Nothing needs creating by hand: `mkswap-swapfile.service` allocates and
    # formats the file on activation if it is absent.
    swapDevices = [
      {
        device = "/swapfile";
        size = 20 * 1024;
      }
    ];

    # `boot.resumeDevice` is deliberately absent. It named the filesystem
    # holding the swapfile so the kernel could find a hibernation image before
    # anything is mounted, and it worked — `resume=` reached the command line
    # and /sys/power/resume was populated. It is removed because this machine
    # cannot hibernate at all, so it only put a resume attempt in front of every
    # boot that could never find an image. Restoring hibernation means
    # restoring this line with the root UUID from `_hardware-generated.nix`.
  };
}
