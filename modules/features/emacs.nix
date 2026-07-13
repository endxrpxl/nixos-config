{ ... }: {
  flake.nixosModules.emacs = { pkgs, ... }: {
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
}
