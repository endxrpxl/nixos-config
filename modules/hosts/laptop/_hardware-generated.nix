# PLACEHOLDER, standing in for generated output. This machine has not been
# installed yet, so nothing below was read off real hardware. Running
# `nix run .#regen-hardware laptop` on the machine overwrites this whole file
# with the real scan — see hardware.nix for what that means for the rest of
# this host.
{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Deliberately all-zero rather than plausible: an impossible UUID can never
  # accidentally match a disk, so a mistaken deploy fails at mount time instead
  # of touching an unintended filesystem.
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
}
