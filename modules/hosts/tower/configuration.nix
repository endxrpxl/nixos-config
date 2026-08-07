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
      self.nixosModules.printing
      self.nixosModules.gaming
      self.nixosModules.vm
      self.nixosModules.emacs
      self.nixosModules.llms
    ];

    networking.hostName = "tower";

    console.keyMap = "uk";

    # The XKB name for the same layout, for the login screen. It cannot be
    # derived from `console.keyMap` above — that is a kbd keymap name, and
    # "uk" is not an XKB layout.
    programs.noctalia-greeter.settings.keyboard.layout = "gb";

    # For mounted drive(s)
    # systemd.tmpfiles.rules = [
    #   "d /mnt/secondary 0755 ${self.lib.username} users -"
    # ];

    # This machine dual-boots Windows: the extra entry points at its
    # bootloader, and Windows expects the RTC in local time.
    boot.loader.limine.extraEntries = ''
      /Windows
        protocol: efi
        path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
    '';
    time.hardwareClockInLocalTime = true;

    home-manager.users.${self.lib.username} = self.homeModules.tower;

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "25.11"; # Did you read the comment?
  };
}
