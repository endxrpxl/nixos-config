{ self, inputs, ... }: {

  flake.nixosConfigurations.laptop = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.laptop
    ];
  };

  # Identity only. Everything machine-agnostic lives in `base`; everything
  # optional lives in the feature module that owns it.
  flake.nixosModules.laptop = { ... }: {
    imports = [
      self.nixosModules.laptopHardware
      self.nixosModules.base
      self.nixosModules.desktop
      self.nixosModules.disk-encryption
      self.nixosModules.fingerprint
      self.nixosModules.power
      self.nixosModules.printing
      self.nixosModules.vm
      self.nixosModules.emacs
      self.nixosModules.llms
    ];

    networking.hostName = "laptop";

    console.keyMap = "de";

    programs.noctalia-greeter.settings.keyboard.layout = "de";

    home-manager.users.${self.lib.username} = self.homeModules.laptop;

    system.stateVersion = "26.05";
  };
}
