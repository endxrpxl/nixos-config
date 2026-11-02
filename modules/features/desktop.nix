{ self, inputs, ... }: {
  # The graphical session: login screen, compositor, shell, theming and fonts.
  # The applications run inside it live in `apps`.
  flake.nixosModules.desktop = { config, pkgs, ... }: {
    imports = [
      inputs.noctalia-greeter.nixosModules.default
      inputs.umbriel.nixosModules.default
    ];

    home-manager.users.${self.lib.username}.imports = [ self.homeModules.desktop ];

    # A graphical session is what needs the GPU drivers, so this belongs to
    # the feature rather than to shared policy. Same reasoning that puts
    # the 32-bit drivers in `gaming`.
    hardware.graphics.enable = true;

    programs.noctalia = {
      enable = true;
      recommendedServices.enable = true;
    };
    hardware.bluetooth.powerOnBoot = false;

    # The login screen. Only the settings no machine can differ on live here.
    services.displayManager.noctalia-greeter = {
      enable = true;
      settings = {
        session.default = "umbriel";

        # The host's layout, as set once in its `services.xserver.xkb`.
        keyboard = {
          inherit (config.services.xserver.xkb) layout variant;
        };

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

    # The compositor. The cache serves the `cachix` branch the flake input
    # tracks, so umbriel and its portal are not compiled locally. umbriel
    # brings its own Xwayland.
    programs.umbriel.enable = true;
    nix.settings = {
      extra-substituters = [ "https://umbriel.cachix.org" ];
      extra-trusted-public-keys = [
        "umbriel.cachix.org-1:JfNq/2yg2S6D6z4Z2dVSZrZlDPQTKtexB6GAVLD98nw="
      ];
    };

    # The Secret Service that apps keep logins in, unlocked at login. The niri
    # module used to enable it; umbriel's does not.
    services.gnome.gnome-keyring.enable = true;

    environment.systemPackages = with pkgs; [
      # The terminal umbriel's Mod+T opens.
      kitty

      bibata-cursors
      whitesur-icon-theme
      colloid-icon-theme
      papirus-icon-theme

      # noctalia's GTK template sets gtk-theme to adw-gtk3/adw-gtk3-dark, but
      # only `if theme_exists`. Without this it silently applies its colours to
      # GTK4 apps and leaves default Adwaita around them, which reads as a bug
      # rather than as a missing package.
      adw-gtk3
    ];

    fonts.packages = with pkgs; [
      roboto
      roboto-mono
      inter
      nerd-fonts.roboto-mono

      noto-fonts
    ];

    # easyeffects reads dconf for its preset paths.
    programs.dconf.enable = true;

    services.udev.packages = [ pkgs.wooting-udev-rules ];
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

      # The hostname picks each program's per-host file, so no host has to
      # name its files a second time and get it wrong.
      host = osConfig.networking.hostName;
    in
    {
      xdg = {
        configFile = {
          "kitty/kitty.conf" = authored "kitty/kitty.conf";

          # config.toml is shared and includes host.toml by name. The
          # indirection lives in this symlink rather than in the file's text,
          # so every host reads the same config.toml. noctalia.toml is theme
          # output and not linked; config.toml includes it as optional, so no
          # seed file is needed.
          "umbriel/config.toml" = authored "umbriel/config.toml";
          "umbriel/host.toml" = authored "umbriel/hosts/${host}.toml";

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

          # The one exception to linking only files a human writes. EasyEffects
          # saves its settings through these links, so changes made in its GUI
          # land in the repo as diffs to commit. easyeffectsrc names the audio
          # devices, which only the host knows; the rc format has no include,
          # so the host half is selected by this symlink, noctalia-style. The
          # plugin files are shared.
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

      # Home Manager owns the GTK settings files here. noctalia's GTK template
      # writes gtk.css and dconf rather than settings.ini, so home-manager is
      # the only writer. `force` is required because the previous
      # dms-shell/matugen theming left those files behind as plain files, and
      # activation would otherwise refuse to clobber them.
      gtk = {
        enable = true;
        iconTheme = {
          package = pkgs.whitesur-icon-theme;
          name = "WhiteSur-dark";
        };
        gtk2.force = true;
      };

      # Every authored link points into the checkout at `dotConfig`. Without
      # one there they would all dangle, so activation stops before writing
      # any of them.
      home.activation.requireCheckout = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        if [ ! -d "${self.lib.dotConfig}" ]; then
          errorEcho "No checkout at ${self.lib.repoDir}. The dotfile links point there, so clone the repo to that path."
          exit 1
        fi
      '';

      xdg.configFile."gtk-3.0/settings.ini".force = true;
      xdg.configFile."gtk-4.0/settings.ini".force = true;

      # noctalia rewrites this whenever the theme changes, so it is runtime
      # output and is not linked. kitty.conf includes it, and kitty warns at
      # startup when the include is missing, which it is until noctalia has
      # run once. Keep in step with that include line.
      home.activation.seedNoctaliaTemplateTargets = self.lib.seedFiles lib [
        ".config/kitty/themes/noctalia.conf"
      ];

      # 20 to match umbriel's `[input.cursor]` and the greeter's `cursor.size`.
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
