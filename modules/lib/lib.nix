{ self, lib, ... }: {
  flake = {
    username = lib.mkDefault "ansgar";
    homeDir = "/home/${self.username}";
    dotDir = "${self.homeDir}/nixos-config/.dotfiles";
    dotConfig = "${self.dotDir}/.config";
    stateDir = "${self.dotDir}/.local/state";
  };
}