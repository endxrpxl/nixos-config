{ inputs, ... }:
{
  # Hardware in two halves. `_hardware-generated.nix` is machine truth, written
  # by `nix run .#regen-hardware` on the machine itself and never edited by
  # hand; this wrapper holds everything a human decided. Rescanning hardware
  # therefore overwrites exactly one file, leaves the decisions alone, and
  # arrives as a reviewable diff — rather than reading /etc/nixos impurely at
  # eval time, which would put the host outside the verification surface.
  flake.nixosModules.laptopHardware =
    { pkgs, ... }:
    let
      swapfile = "/swapfile";

      # Where `/swapfile` physically starts on the root device, in 4 KiB units,
      # read with `sudo filefrag -b4096 -v /swapfile` and taken from extent 0's
      # physical offset. The kernel wants this in units of PAGE_SIZE; ext4's
      # block size here is also 4096, so the number transfers unchanged.
      #
      # It is a hand-copied constant because a kernel parameter has to be fixed
      # at build time, and it is guarded below because it can silently stop
      # being true. See `check-resume-offset` for what goes wrong without that.
      resumeOffset = 46749696;
    in
    {
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

      # Swap, for paging under memory pressure and for the hibernation image.
      # 20 GiB on 16 GiB of RAM leaves room for the whole of RAM plus paging.
      #
      # This sits in the hand-written half rather than in `power` because it is
      # a fact about this machine's RAM and disk, and it has to be read
      # alongside the `swapDevices = [ ]` next door. It cannot move *into* that
      # file: `nixos-generate-config` reads /proc/swaps and deliberately skips
      # entries of type `file`, on the grounds that swap files are declared by
      # hand — so a rescan will never emit this, no matter how the machine is
      # running when it is run. `swapDevices` is a list option, so the two
      # definitions concatenate and a rescan cannot eat this one.
      #
      # Nothing needs creating by hand: `mkswap-swapfile.service` allocates and
      # formats the file on activation if it is absent.
      swapDevices = [
        {
          device = swapfile;
          size = 20 * 1024;
        }
      ];

      # Finding a hibernation image takes two facts, and a swapfile needs both.
      # `resumeDevice` names the block device holding the filesystem, which the
      # kernel can reach before anything is mounted; `resume_offset` says where
      # in it the file starts, because the kernel has no filesystem driver at
      # that point and cannot look the file up by name.
      #
      # The device is the root UUID from `_hardware-generated.nix`, repeated
      # rather than referenced: `config.fileSystems."/".device` would read it
      # back, and it would then be one edit away from silently naming a
      # filesystem that does not hold the swapfile.
      #
      # An earlier hibernation attempt set this line and not the offset. It
      # wrote images and never found them, and the failure was invisible next
      # to a kernel that was refusing to hibernate anyway — see
      # docs/adr/0007-hibernate-to-the-swapfile.md.
      boot.resumeDevice = "/dev/disk/by-uuid/7003dde5-002a-4bec-9345-76d13aeee614";
      boot.kernelParams = [ "resume_offset=${toString resumeOffset}" ];

      # The offset above is a build-time copy of a runtime fact, and the two can
      # part company without anything complaining: `mkswap-swapfile.service`
      # recreates `/swapfile` whenever it is missing, and ext4 puts the new one
      # wherever it likes. Nothing fails when that happens. Hibernation still
      # writes an image, the kernel still looks at `resume_offset` on the next
      # boot, finds no image signature there, and boots normally — so the
      # machine comes up having forgotten a session, which is exactly what a
      # crash looks like. This unit is here so that failure has a name.
      #
      # Checking rather than computing is the point. Deriving the offset at
      # activation could not fix the boot that has already happened, and it
      # would hide the drift instead of reporting it.
      systemd.services.check-resume-offset = {
        description = "Check that ${swapfile} still starts at the offset resume_offset names";

        after = [ "mkswap-swapfile.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        # `-b4096` pins the units to what `resume_offset` means, rather than
        # trusting filefrag's default to keep matching the filesystem's block
        # size. Extent 0 is the one the kernel resumes from; later extents are
        # the file's own business.
        script = ''
          set -eu

          actual=$(${pkgs.e2fsprogs}/bin/filefrag -b4096 -v ${swapfile} \
            | ${pkgs.gawk}/bin/awk '$1 == "0:" { sub(/\.\..*/, "", $4); print $4; exit }')

          if [ -z "$actual" ]; then
            echo "could not read the first extent of ${swapfile}" >&2
            exit 1
          fi

          if [ "$actual" != "${toString resumeOffset}" ]; then
            echo "${swapfile} starts at $actual, but resume_offset says ${toString resumeOffset}" >&2
            echo "hibernation will write images this machine cannot find on resume" >&2
            echo "fix: set resumeOffset to $actual in modules/hosts/laptop/hardware.nix" >&2
            exit 1
          fi
        '';
      };
    };
}
