{ self, lib, ... }: {
  flake = {
    username = lib.mkDefault "ansgar";
    dotDir = "/home/${self.username}/nixos-config/.dotfiles";
    dotConfig = "${self.dotDir}/.config";
    stateDir = "${self.dotDir}/.local/state";
  };
}