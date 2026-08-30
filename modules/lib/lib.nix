{ self, lib, ... }: {
  # Nested under `lib` because Nix recognises only a fixed set of flake
  # outputs and warns about anything else on every `nix flake check`; `lib` is
  # the recognized output that permits arbitrary contents.
  #
  # Declared as an option so each constant stays its own definition. Left
  # undeclared, flake-parts takes the whole attrset as one opaque value and
  # property annotations inside it (`mkDefault` below) are never resolved,
  # leaking into call sites as attrsets.
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
  };

  config.flake.lib = {
    username = lib.mkDefault "ansgar";
    homeDir = "/home/${self.lib.username}";
    repoDir = "${self.lib.homeDir}/nixos-config";
    dotDir = "${self.lib.repoDir}/.dotfiles";
    dotConfig = "${self.lib.dotDir}/.config";

    # Authored dotfiles only: files a human edits, linked out of the store so an
    # edit takes effect without a rebuild. Anything a running program writes is
    # deliberately NOT linked, so it never reaches this repo.
    #
    # The path is checked against the flake source at eval time, so a typo fails
    # `nix flake check` instead of quietly producing a dangling symlink. That
    # matters most for the per-host files, whose name comes from the hostname
    # and so is never written out literally at the call site.
    #
    # The check and the link do not read the same thing: the assertion looks in
    # the flake source, the link points at `dotConfig` on disk. It therefore
    # catches a wrong path, not a checkout in the wrong place. Clone the repo
    # anywhere but `repoDir` and every link dangles with the check still green.
    #
    # `config` is the home-manager configuration.
    authoredDotfile =
      config: path:
      let
        src = self + "/.dotfiles/.config/${path}";
      in
      assert lib.assertMsg (builtins.pathExists src)
        "authored dotfile '.dotfiles/.config/${path}' does not exist";
      {
        source = config.lib.file.mkOutOfStoreSymlink "${self.lib.dotConfig}/${path}";
        force = true;
      };

    # Files created empty on activation, and only if they do not already exist.
    # For paths a program writes at runtime that something else needs present
    # before it has ever run: niri refuses to start when an `include` target is
    # missing, and on a fresh machine no shell has written one yet.
    #
    # Never touches an existing file, so runtime content survives a rebuild.
    # `hmLib` is the home-manager module's `lib`; paths are relative to $HOME.
    seedFiles =
      hmLib: paths:
      hmLib.hm.dag.entryAfter [ "writeBoundary" ] (
        lib.concatMapStringsSep "\n" (path: ''
          run mkdir -p "$(dirname "$HOME/${path}")"
          [ -e "$HOME/${path}" ] || run touch "$HOME/${path}"
        '') paths
      );
  };
}
