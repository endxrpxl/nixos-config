{ self, inputs, ... }: {

  flake.nixosConfigurations.desktop = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.desktopConfiguration
    ];
  };

  flake.nixosModules.desktopConfiguration = { pkgs, ... }: {
    imports = [
      self.nixosModules.desktopHardware
      inputs.home-manager.nixosModules.default
      self.nixosModules.desktop
      self.nixosModules.gaming
      self.nixosModules.vm
      self.nixosModules.emacs
      self.nixosModules.llms
    ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    # for scanning
    hardware.sane.enable = true;
    hardware.sane.extraBackends = [ pkgs.sane-airscan ];

    nix.optimise.automatic = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nixpkgs.overlays = [ self.overlays.default ];
    nixpkgs.config.allowUnfree = true;

    boot.loader = {
      limine = {
        enable = true;
        maxGenerations = 5;
        extraEntries = ''
          /Windows
            protocol: efi
            path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
        '';
      };
      efi.canTouchEfiVariables = true;
      timeout = 1;
    };
    time.hardwareClockInLocalTime = true;

    boot.kernelPackages = pkgs.linuxPackages_latest; # Fix CVE-2026-31431

    # For mounted drive(s)
    # systemd.tmpfiles.rules = [
    #   "d /mnt/secondary 0755 ${self.lib.username} users -"
    # ];

    networking = {
      hostName = "nixos";
      networkmanager.enable = true;
      nameservers = [
        "1.1.1.1"
        "1.0.0.1"
      ];
      # useDHCP = false;
    };

    time.timeZone = "Europe/Berlin";

    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocaleSettings = {
        LC_ADDRESS = "de_DE.UTF-8";
        LC_IDENTIFICATION = "de_DE.UTF-8";
        LC_MEASUREMENT = "de_DE.UTF-8";
        LC_MONETARY = "de_DE.UTF-8";
        LC_NAME = "de_DE.UTF-8";
        LC_NUMERIC = "de_DE.UTF-8";
        LC_PAPER = "de_DE.UTF-8";
        LC_TELEPHONE = "de_DE.UTF-8";
        LC_TIME = "de_DE.UTF-8";
      };
    };

    services = {
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
      udisks2.enable = true;
      gvfs.enable = true;
    };

    console.keyMap = "uk";

    security.rtkit.enable = true;
    security.polkit.enable = true;

    users.users.${self.lib.username} = {
      isNormalUser = true;
      description = self.lib.username;
      extraGroups = [
        "networkmanager"
        "wheel"
        "storage"
        "scanner"
        "lp"
      ];
    };
    home-manager.users.${self.lib.username} = self.homeModules.${self.lib.username};

    programs.starship.enable = true;
    programs.nh = {
      enable = true;
      flake = self.lib.repoDir;
    };

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      glibc
    ];

    environment.systemPackages = with pkgs; [
      git
      gh
      neovim

      nixfmt
      nixd
      nil
      manix

      devenv
    ];

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "25.11"; # Did you read the comment?
  };
}
