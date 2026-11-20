{ self, inputs, ... }: {
  # The applications a person opens, as opposed to the graphical session they
  # open them in, which is `desktop`.
  flake.nixosModules.apps = { pkgs, ... }: {
    home-manager.users.${self.lib.username}.imports = [ self.homeModules.apps ];

    # Bitwarden is the SSH agent (see `SSH_AUTH_SOCK` below). gnome-keyring
    # would otherwise start gcr's agent as well. The keyring itself stays.
    services.gnome.gcr-ssh-agent.enable = false;

    programs.firefox.enable = true;
    programs.thunderbird.enable = true;

    programs.obs-studio = {
      enable = true;

      plugins = with pkgs.obs-studio-plugins; [
        obs-pipewire-audio-capture
        obs-vaapi # VA-API hardware encoding
      ];
    };

    services.flatpak = {
      enable = true;
    };

    environment.systemPackages = with pkgs; [
      spotify
      zed-editor
      bitwarden-desktop
      (discord.override {
        # withVencord = true;
      })


      loupe
      evince
      vlc
      file-roller
      nemo-with-extensions
      pinta

      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

      inputs.oneclient.packages.${pkgs.stdenv.hostPlatform.system}.default

      eduvpn-client

      libreoffice
    ];
  };

  flake.homeModules.apps = { ... }: {
    # Nemo's "Open in Terminal" reads the Cinnamon terminal setting.
    dconf.settings."org/cinnamon/desktop/applications/terminal" = {
      exec = "kitty";
    };

    # Bitwarden desktop serves the SSH agent.
    programs.bash.bashrcExtra = ''
      export SSH_AUTH_SOCK=${self.lib.homeDir}/.bitwarden-ssh-agent.sock
    '';
  };
}
