{ self, ... }: {
  
  flake.homeModules.${self.username} = { ... }: {
    imports = [
      self.homeModules.desktop
    ];

    home.stateVersion = "25.11";
  };
}