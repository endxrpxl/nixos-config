{ ... }: {
  flake.nixosModules.dev =
    { pkgs, ... }:
    {
      # nix-ld lets unpatched dynamically-linked binaries run. Language
      # toolchain downloads, `devenv` shells, editor-installed LSP servers.
      # The library list is the minimum such binaries reliably expect.
      programs.nix-ld.enable = true;
      programs.nix-ld.libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        glibc
      ];

      environment.systemPackages = with pkgs; [
        gh

        nixfmt
        nixd
        nil
        manix

        devenv
      ];
    };
}
