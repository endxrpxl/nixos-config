{ inputs, ... }: {

  flake.nixosModules.laptopHardware =
    {
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")

        # ThinkPad T14 Gen 3, Intel (12th gen). nixos-hardware has no
        # `intel-gen3` module — the Intel line jumps gen1 to gen6 — so the
        # generic T14 module (backlight and touchpad quirks, SSD and laptop
        # defaults) is paired with the Intel CPU module, which also brings in
        # the integrated graphics configuration.
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14
        inputs.nixos-hardware.nixosModules.common-cpu-intel
      ];

      # PLACEHOLDER. This machine has not been installed yet, so none of the
      # values below were read off real hardware. They are deliberately
      # all-zero rather than plausible: an impossible UUID can never
      # accidentally match a disk, and a mistaken deploy fails at mount time
      # instead of touching an unintended filesystem.
      #
      # `nix flake check` builds this host green regardless — the build never
      # touches a disk — so the check proves this configuration evaluates and
      # builds, and proves nothing at all about whether it boots. See
      # docs/adr/0003-placeholder-host-in-the-verification-surface.md.
      #
      # On arrival, replace the UUIDs from `nixos-generate-config`, set
      # `console.keyMap` in configuration.nix to the real layout, confirm
      # `system.stateVersion` matches the release actually installed, and
      # delete this warning.
      warnings = [
        ''
          The `laptop` host is a placeholder: its filesystem UUIDs and console
          keymap are not real values and it will not boot as configured. See
          modules/hosts/laptop/hardware.nix.
        ''
      ];

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/0000-0000";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      boot.initrd.availableKernelModules = [
        "nvme"
        "xhci_pci"
        "thunderbolt"
        "usbhid"
        "usb_storage"
        "sd_mod"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.extraModulePackages = [ ];

      swapDevices = [ ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
