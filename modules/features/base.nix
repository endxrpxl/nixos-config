{ self, inputs, ... }: {

  # Policy every host shares. Two tests decide what lives here, and a setting
  # must pass both:
  #
  #   1. Varying it per host would be a bug or a fleet-wide preference
  #      deliberately held constant — not something a machine legitimately
  #      differs on. Anything that fails this is host identity.
  #   2. No feature module honestly owns it. Graphics belong to `desktop`,
  #      32-bit support to `gaming`, mDNS to `printing`. Anything that fails
  #      this belongs to that feature, not here.
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

      programs.starship.enable = true;
      programs.nh = {
        enable = true;
        flake = self.lib.repoDir;
      };

      # nix-ld lets unpatched dynamically-linked binaries run — language
      # toolchain downloads, `devenv` shells, editor-installed LSP servers.
      # The library list is the minimum such binaries reliably expect.
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
