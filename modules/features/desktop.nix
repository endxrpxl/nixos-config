{ self, inputs, ... }: {

  flake.nixosModules.desktop = { pkgs, ... }: {
    imports =[
      self.nixosModules.zen
    ];
    services.displayManager.dms-greeter = {
      enable = true;
      compositor.name = "niri";
      configHome = "/home/ansgar";
    };
    programs.dms-shell= {
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

    environment.systemPackages = with pkgs; [
      kitty
      nautilus
      vesktop
      spotify
      vscode
      bitwarden-desktop
      
      xwayland-satellite

      bibata-cursors
      whitesur-icon-theme
      colloid-icon-theme
    ];

    fonts.packages = with pkgs; [
      roboto
      roboto-mono
      nerd-fonts.roboto-mono
    ];
  };

  flake.homeModules.desktop = { config, ... }: 
  let 
    mkLink = config.lib.file.mkOutOfStoreSymlink;
    mkConfigLink = x: mkLink "${self.dotConfig}/${x}";
  in {
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
  };
}