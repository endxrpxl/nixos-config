{ self, ... }: {
  flake.nixosModules.emacs = { pkgs, ... }: {
    home-manager.users.${self.lib.username}.imports = [ self.homeModules.emacs ];

    environment.systemPackages = with pkgs; [
      emacs
      ripgrep
      coreutils
      fd
      clang
    ];

    fonts.packages = with pkgs; [
      symbola
      nerd-fonts.symbols-only
    ];
  };

  # Doom Emacs installs its `doom` command under ~/.config/emacs/bin.
  flake.homeModules.emacs = { ... }: {
    programs.bash.bashrcExtra = ''
      export PATH="$HOME/.config/emacs/bin:$PATH"
    '';
  };
}
