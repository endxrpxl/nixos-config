{ self, inputs, ... }: {
  flake.nixosModules.desktop = { pkgs, ... }: {
    imports = [
      self.nixosModules.zen
      inputs.nix-flatpak.nixosModules.nix-flatpak
    ];

    # A graphical session is what needs the GPU drivers, so this belongs to
    # the feature rather than to shared policy — the same reasoning that puts
    # the 32-bit drivers in `gaming`.
    hardware.graphics.enable = true;

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
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      authored = self.lib.authoredDotfile config;

      # The per-host half of each config is selected by hostname rather than
      # named in the host's home module: ADR-0002 makes the hostname the host's
      # identity, and restating it here would be a second place to get it wrong.
      host = osConfig.networking.hostName;
    in
    {
      xdg = {
        configFile = {
          "kitty/kitty.conf" = authored "kitty/kitty.conf";
          "DankMaterialShell/settings.json" = authored "DankMaterialShell/settings.json";

          # config.kdl is shared and ends with `include "host.kdl"`; the
          # indirection lives in this symlink rather than in the file's text, so
          # every host reads the same config.kdl.
          "niri/config.kdl" = authored "niri/config.kdl";
          "niri/host.kdl" = authored "niri/hosts/${host}.kdl";

          "matugen" = (authored "matugen") // {
            recursive = true;
          };
        };
        stateFile = {
          "DankMaterialShell/session.json" = {
            source = config.lib.file.mkOutOfStoreSymlink "${self.lib.stateDir}/DankMaterialShell/session.json";
            force = true;
          };
        };

        userDirs = {
          createDirectories = true;
          music = null;
          templates = null;
        };
      };

      # `niri` is no longer linked as a whole directory, so the snippets DMS
      # regenerates under ~/.config/niri/dms/ are now unmanaged — which is the
      # point, they are runtime output and do not belong in the repo. But
      # config.kdl still includes them, and niri refuses to start on a missing
      # include, so they have to exist before DMS has ever run.
      # Keep in sync with the `include "dms/..."` lines in niri/config.kdl.
      home.activation.seedNiriDmsIncludes = self.lib.seedFiles lib (
        map (f: ".config/niri/dms/${f}.kdl") [
          "binds"
          "colors"
          "cursor"
          "layout"
          "windowrules"
        ]
      );

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
