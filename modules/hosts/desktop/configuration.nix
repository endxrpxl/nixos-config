{ self, inputs, ... }: {

  flake.nixosConfigurations.desktop = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.desktopConfiguration
    ];
  };

  flake.nixosModules.desktopConfiguration = { config, pkgs, ... }: {
    imports = [
      self.nixosModules.desktopHardware
      inputs.home-manager.nixosModules.default
      self.nixosModules.desktop
      self.nixosModules.gaming
    ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    nix.optimise.automatic = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nixpkgs.config.allowUnfree = true;

    boot.loader = {
      grub ={
        enable = true;
        devices = [ "nodev" ];
        efiSupport = true;
        useOSProber = true;
        configurationLimit = 5;
      };
      efi.canTouchEfiVariables = true;
      timeout = 1;
    };
    time.hardwareClockInLocalTime = true;

    boot.kernelPackages = pkgs.linuxPackages_latest; # Fix CVE-2026-31431

    # For mounted drive(s)
    systemd.tmpfiles.rules = [
      "d /mnt/secondary 0755 ${self.username} users -"
    ];

    networking = {
      hostName = "nixos";
      networkmanager.enable = true;
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
      printing.enable = true;
      pulseaudio.enable = false;
      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
      xserver = {
        enable = true;
        videoDrivers = [ "amdgpu" ];
        xkb = {
          layout = "gb";
          variant = "";
        };
      };
    };

    console.keyMap = "uk";


    security.rtkit.enable = true;

    users.users.${self.username} = {
      isNormalUser = true;
      description = self.username;
      extraGroups = [ "networkmanager" "wheel" ];
    };
    home-manager.users.${self.username} = self.homeModules.${self.username};

    programs.starship.enable = true;
    programs.nh = {
      enable = true;
      flake = "${self.homeDir}/nixos-config";
    };

    environment.systemPackages = with pkgs; [
      git
      neovim

      nixfmt
      nil
      manix
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