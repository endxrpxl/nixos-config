{ self, inputs, ... }: {

  flake.nixosConfigurations.tower = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.tower
    ];
  };

  # Identity only. Everything machine-agnostic lives in `base`; everything
  # optional lives in the feature module that owns it.
  flake.nixosModules.tower = { ... }: {
    imports = [
      self.nixosModules.towerHardware
      self.nixosModules.base
      self.nixosModules.desktop
      self.nixosModules.apps
      self.nixosModules.dev
      self.nixosModules.printing
      self.nixosModules.gaming
      self.nixosModules.vm
      self.nixosModules.emacs
      self.nixosModules.llms
    ];

    networking.hostName = "tower";

    # The only place this host's keyboard layout is written. See
    # `console.useXkbConfig` in `base` for who reads it.
    services.xserver.xkb = {
      layout = "gb,gb";
      variant = ",intl";
    };

    # This machine dual-boots Windows: the extra entry points at its
    # bootloader, and Windows expects the RTC in local time.
    boot.loader.limine.extraEntries = ''
      /Windows
        protocol: efi
        path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
    '';
    time.hardwareClockInLocalTime = true;

    # Steam's ports open here only. The laptop joins public networks such as
    # eduroam, and this machine stays on the home network.
    programs.steam = {
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    # The release this host was first installed with. Never change it.
    system.stateVersion = "25.11";
  };
}
