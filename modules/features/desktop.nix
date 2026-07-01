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

    services = {
      printing = {
        enable = true;
        drivers = with pkgs; [
          cups-filters
          cups-browsed
        ];
      };
      avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };
    };

    services.displayManager.dms-greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = "/home/${self.username}";
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

    # bitwarden-desktop still pins EOL Electron 39 (NixOS/nixpkgs#526914).
    # Accept the risk window until upstream bumps it; nixpkgs already
    # aliases `electron_39 = electron_39-bin` so no overlay is needed.
    # Remove this once bitwarden-desktop moves to a supported Electron.
    nixpkgs.config.permittedInsecurePackages = [
      "electron-39.8.10"
    ];

    environment.systemPackages = with pkgs; [
      kitty
      vesktop
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

      bibata-cursors
      whitesur-icon-theme
      colloid-icon-theme
      code-cursor
      zed-editor
      claude-code
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
      mkConfigLink = x: mkLink "${self.dotConfig}/${x}";
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
          "vesktop/settings/settings.json" = {
            source = mkConfigLink "vesktop/settings/settings.json";
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
            source = mkLink "${self.stateDir}/DankMaterialShell/session.json";
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
        gtk.enable = true;
        x11.enable = true;
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 16;
      };
    };
}
