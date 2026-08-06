{ self, inputs, ... }: {

  # Policy every host shares. A setting belongs here only if changing it on
  # one host but not another would be a bug rather than a preference —
  # anything a machine legitimately differs on stays in the host, and anything
  # a host opts into is a feature module of its own.
  #
  # `base` is an ordinary feature module: hosts import it explicitly, exactly
  # as they import `desktop` or `gaming`. It carries no options. When a host
  # eventually needs to diverge on something declared here, the fix is
  # `mkDefault` on this side, not a new option — the module system already is
  # the configuration language.
  flake.nixosModules.base =
    { pkgs, ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.default
      ];

      hardware.graphics.enable = true;

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

      # Tracks the newest kernel for hardware support — laptop-era hardware in
      # particular is usually supported before it reaches the LTS series. This
      # also carried the fix for CVE-2026-31431.
      boot.kernelPackages = pkgs.linuxPackages_latest;

      networking = {
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

      security.rtkit.enable = true;
      security.polkit.enable = true;

      users.users.${self.lib.username} = {
        isNormalUser = true;
        description = self.lib.username;
        extraGroups = [
          "networkmanager"
          "wheel"
          "storage"
        ];
      };

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
    };

  flake.homeModules.base = { ... }: {
    programs.bash = {
      enable = true;
      bashrcExtra = ''
        export SSH_AUTH_SOCK=${self.lib.homeDir}/.bitwarden-ssh-agent.sock
        export PATH="$HOME/.config/emacs/bin:$PATH"

        ip-fix () {
            sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
            sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
        }
      '';
    };
  };
}
