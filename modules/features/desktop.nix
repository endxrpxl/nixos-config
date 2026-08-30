{ self, inputs, ... }: {
  flake.nixosModules.desktop = { pkgs, ... }: {
    imports = [
      self.nixosModules.zen
      inputs.nix-flatpak.nixosModules.nix-flatpak
      inputs.noctalia-greeter.nixosModules.default
    ];

    # A graphical session is what needs the GPU drivers, so this belongs to
    # the feature rather than to shared policy. Same reasoning that puts
    # the 32-bit drivers in `gaming`.
    hardware.graphics.enable = true;

    programs.noctalia = {
      enable = true;
      recommendedServices.enable = true;
    };
    hardware.bluetooth.powerOnBoot = false;

    # The login screen. Only the settings no machine can differ on live here;
    # `keyboard.layout` is host identity and each host adds its own.
    programs.noctalia-greeter = {
      enable = true;
      settings = {
        session.default = "niri";

        # The greeter runs as its own user and cannot see `home.pointerCursor`
        # below, so it is given the store path outright rather than relying on
        # the theme being installed somewhere it happens to look.
        cursor = {
          theme = "Bibata-Modern-Ice";
          size = 20;
          path = "${pkgs.bibata-cursors}/share/icons";
        };

        # `appearance` is left out on purpose: declarative keys beat synced
        # ones, so declaring a palette would make Settings → Security →
        # Noctalia Greeter → Sync Now silently do nothing.
      };
    };

    programs.niri.enable = true;
    programs.firefox.enable = true;
    programs.thunderbird.enable = true;

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

    environment.systemPackages = with pkgs; [
      kitty
      spotify
      zed-editor
      bitwarden-desktop
      (discord.override {
        withOpenASAR = true;
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

      # noctalia's GTK template sets gtk-theme to adw-gtk3/adw-gtk3-dark, but
      # only `if theme_exists`. Without this it silently applies its colours to
      # GTK4 apps and leaves default Adwaita around them, which reads as a bug
      # rather than as a missing package.
      adw-gtk3

      libreoffice
    ];

    fonts.packages = with pkgs; [
      roboto
      roboto-mono
      nerd-fonts.roboto-mono

      noto-fonts
    ];

    # easyeffects reads dconf for its preset paths.
    programs.dconf.enable = true;
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
      # named in the host's home module: the hostname is the host's identity,
      # and restating it here would be a second place to get it wrong.
      host = osConfig.networking.hostName;
    in
    {
      xdg = {
        configFile = {
          "kitty/kitty.conf" = authored "kitty/kitty.conf";

          # config.kdl is shared and ends with `include "host.kdl"`; the
          # indirection lives in this symlink rather than in the file's text, so
          # every host reads the same config.kdl.
          "niri/config.kdl" = authored "niri/config.kdl";
          "niri/host.kdl" = authored "niri/hosts/${host}.kdl";

          # Only the config half of noctalia's split is linked. The settings UI
          # writes ~/.local/state/noctalia/settings.toml, which is runtime state
          # and stays out of this repo, so a tweak in the UI no longer dirties
          # the working tree, and keeping one means copying it across by hand
          # with `noctalia config export merged`.
          #
          # config.toml includes shared/base.toml, so load order is written down
          # rather than inferred from the alphabetical order two filenames happen
          # to have. The shared half sits in a subdirectory because noctalia
          # autoloads the root of its config directory but not subdirectories.
          "noctalia/config.toml" = authored "noctalia/hosts/${host}.toml";
          "noctalia/shared/base.toml" = authored "noctalia/shared/base.toml";

          # EasyEffects writes these itself, so this re-authors its runtime
          # dumps. easyeffectsrc names the audio devices, which only the host
          # knows; the rc format has no include, so the host half is selected
          # by this symlink, noctalia-style. The plugin files are shared.
          "easyeffects/db/easyeffectsrc" = authored "easyeffects/db/hosts/${host}rc";
          "easyeffects/db/bassEnhancerrc" = authored "easyeffects/db/bassEnhancerrc";
          "easyeffects/db/deepfilternetrc" = authored "easyeffects/db/deepfilternetrc";
          "easyeffects/db/rnnoiserc" = authored "easyeffects/db/rnnoiserc";
        };

        userDirs = {
          createDirectories = true;
          music = null;
          templates = null;
        };
      };

      # noctalia rewrites both of these whenever the theme changes, so they are
      # runtime output and are not linked. Their includes are authored into
      # config.kdl and kitty.conf, which read them before noctalia has ever run:
      # niri refuses to start on a missing include, kitty only complains.
      # Keep in step with those two include lines.
      home.activation.seedNoctaliaTemplateTargets = self.lib.seedFiles lib [
        ".config/niri/noctalia.kdl"
        ".config/kitty/themes/noctalia.conf"
      ];

      # 20 to match niri's `xcursor-size` and the greeter's `cursor.size`.
      home.pointerCursor = {
        enable = true;
        gtk.enable = true;
        x11.enable = true;
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 20;
      };

      services.easyeffects.enable = true;
    };
}
