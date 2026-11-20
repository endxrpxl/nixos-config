{ self, inputs, ... }: {
  flake.nixosModules.base =
    { pkgs, ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.default
      ];

      # Home Manager uses this system's nixpkgs, `allowUnfree` included,
      # rather than evaluating a second copy. Each feature with a
      # home half imports that half itself, so a host selects a feature once.
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${self.lib.username}.imports = [ self.homeModules.base ];
      };

      nix.optimise.automatic = true;

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      nixpkgs.config.allowUnfree = true;

      # Bootloader choice is shared: two hosts on two bootloaders would mean
      # two sets of boot failures to learn to debug, for no gain. Only the
      # entries themselves are host-specific.
      boot.loader = {
        limine = {
          enable = true;
          maxGenerations = 5;
        };
        efi.canTouchEfiVariables = true;
        timeout = 1;
      };

      # Compressed swap in RAM, up to half of it, for paging under memory
      # pressure. Neither host hibernates, so neither needs swap on disk.
      zramSwap.enable = true;

      # Tracks the newest kernel for hardware support. Laptop-era hardware in
      # particular is usually supported before it reaches the LTS series.
      boot.kernelPackages = pkgs.linuxPackages_latest;

      networking = {
        networkmanager.enable = true;
      };

      # Each host sets its layout once, in `services.xserver.xkb`. The console
      # derives its keymap from that, the greeter reads it in `desktop`, and
      # umbriel gets it from systemd-localed.
      console.useXkbConfig = true;

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

      # PipeWire replaces PulseAudio outright, so the latter is switched off
      # rather than left to the NixOS default. `pulse.enable` keeps the
      # PulseAudio client API for applications that still speak it. The
      # 32-bit ALSA half of this lives in `gaming`, alongside the 32-bit
      # graphics drivers it exists to serve.
      services = {
        pulseaudio.enable = false;
        pipewire = {
          enable = true;
          alsa.enable = true;
          pulse.enable = true;
        };
        udisks2.enable = true;
        gvfs.enable = true;
      };

      # rtkit is what lets PipeWire acquire realtime scheduling; without it
      # audio glitches under load. polkit is required by the desktop session
      # and by udisks2 for unprivileged mounting.
      security.rtkit.enable = true;
      security.polkit.enable = true;

      # The fleet has exactly one human, so the account is shared policy
      # rather than host identity. Only groups every host needs live here:
      # groups a single concern requires belong to that concern's module, the
      # way `printing` declares `scanner` and `lp` for itself.
      users.users.${self.lib.username} = {
        isNormalUser = true;
        description = self.lib.username;
        extraGroups = [
          "networkmanager"
          "wheel"
          "storage"
        ];
      };

      # Enabled fleet-wide
      programs.starship.enable = true;
      programs.nh = {
        enable = true;
        flake = self.lib.repoDir;

        # Garbage collection. `--keep 5` matches limine's `maxGenerations`, so
        # cleaning never deletes a generation the boot menu still lists.
        clean = {
          enable = true;
          dates = "weekly";
          extraArgs = "--keep 5 --keep-since 14d";
        };
      };

      # git because the flake only sees files in the git index, so working on
      # this repo needs it on every host.
      environment.systemPackages = with pkgs; [
        git
        neovim
      ];
    };

  flake.homeModules.base =
    { osConfig, ... }:
    {
      programs.bash.enable = true;

      # Always the system's value. The two are set at the same install and
      # never change, so a second copy per host could only drift.
      home.stateVersion = osConfig.system.stateVersion;
    };
}
