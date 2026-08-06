{ self, inputs, ... }: {
  flake.nixosModules.desktop = { pkgs, ... }: {
    imports = [
      self.nixosModules.zen
      inputs.nix-flatpak.nixosModules.nix-flatpak
    ];

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = false;
    };

    services.displayManager.dms-greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = self.lib.homeDir;
    };
    programs.dms-shell = {
      enable = true;
      systemd = {
        enable = true;
        restartIfChanged = true;
      };
      quickshell.package = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.quickshell;
    };
    programs.niri.enable = true;
    programs.dsearch.enable = true;
    programs.firefox.enable = true;

    programs.obs-studio = {
      enable = true;

      plugins = with pkgs.obs-studio-plugins; [
        obs-pipewire-audio-capture
        obs-vaapi # optional AMD hardware acceleration
      ];
    };

    services.flatpak = {
      enable = true;
    };

    services.power-profiles-daemon.enable = true;

    # # bitwarden-desktop still pins EOL Electron 39 (NixOS/nixpkgs#526914).
    # # Accept the risk window until upstream bumps it; nixpkgs already
    # # Remove this once bitwarden-desktop moves to a supported Electron.
    # nixpkgs.config.permittedInsecurePackages = [
    #   "electron-39.8.10"
    # ];

    environment.systemPackages = with pkgs; [
      kitty
      spotify
      vscode
      bitwarden-desktop
      (discord.override {
        withOpenASAR = true; # can do this here too
        withVencord = true;
      })

      nautilus
      loupe
      evince
      vlc
      file-roller

      xwayland-satellite

      # Not a duplicate of `home.pointerCursor.package` below: dms-greeter runs
      # as its own user and reads the system profile, the session reads the
      # user profile. Dropping this leaves the login screen on the default
      # cursor — a regression `nix flake check` cannot see.
      bibata-cursors
      whitesur-icon-theme
      colloid-icon-theme

      code-cursor
      zed-editor
      claude-code

      libreoffice
    ];

    fonts.packages = with pkgs; [
      roboto
      roboto-mono
      nerd-fonts.roboto-mono

      noto-fonts
    ];
  };

  flake.homeModules.desktop =
    { config, pkgs, ... }:
    let
      mkLink = config.lib.file.mkOutOfStoreSymlink;
      mkConfigLink = x: mkLink "${self.lib.dotConfig}/${x}";
    in
    {
      xdg = {
        configFile = {
          "kitty/kitty.conf" = {
            source = mkConfigLink "kitty/kitty.conf";
            force = true;
          };
          "DankMaterialShell/settings.json" = {
            source = mkConfigLink "DankMaterialShell/settings.json";
            force = true;
          };
          "niri" = {
            source = mkConfigLink "niri";
            recursive = true;
            force = true;
          };
          "matugen" = {
            source = mkConfigLink "matugen";
            recursive = true;
            force = true;
          };
        };
        stateFile = {
          "DankMaterialShell/session.json" = {
            source = mkLink "${self.lib.stateDir}/DankMaterialShell/session.json";
            force = true;
          };
        };

        userDirs = {
          createDirectories = true;
          music = null;
          templates = null;
        };
      };

      home.pointerCursor = {
        enable = true;
        gtk.enable = true;
        x11.enable = true;
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 16;
      };
    };
}
