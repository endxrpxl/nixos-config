{ self, ... }: {

  flake.homeModules.tower = { ... }: {
    imports = [
      self.homeModules.base
      self.homeModules.desktop
    ];

    home.stateVersion = "25.11";
  };
}
