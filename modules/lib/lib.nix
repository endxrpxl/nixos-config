{ self, lib, ... }: {
  # Nested under `lib` because Nix recognises only a fixed set of flake
  # outputs and warns about anything else on every `nix flake check`; `lib` is
  # the recognised output that permits arbitrary contents.
  #
  # Declared as an option so each constant stays its own definition. Left
  # undeclared, flake-parts takes the whole attrset as one opaque value and
  # property annotations inside it — `mkDefault` below — are never resolved,
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
    stateDir = "${self.lib.dotDir}/.local/state";
  };
}
