{ self, ... }: {

  flake.homeModules.laptop = { ... }: {
    imports = [
      self.homeModules.base
      self.homeModules.desktop
    ];

    home.stateVersion = "25.11";
  };
}
