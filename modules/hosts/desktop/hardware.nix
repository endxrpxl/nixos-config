{ self, inputs, ... }: {

  flake.nixosModules.desktopHardware = { config, lib, pkgs, modulesPath, ... }: {
    imports = [ 
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

    boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-amd" ];
    boot.extraModulePackages = [ ];

    fileSystems."/" = { 
      device = "/dev/disk/by-uuid/c22b47fe-e917-44a8-a8ad-59eef815d538";
      fsType = "ext4";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/96A5-A493";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

    swapDevices = [ ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
