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
      self.nixosModules.printing
      self.nixosModules.vm
      self.nixosModules.emacs
      self.nixosModules.llms
    ];

    networking.hostName = "laptop";

    # PLACEHOLDER — this machine's keyboard layout has not been confirmed.
    # `de` matches the LC_* settings in `base`. See hardware.nix.
    console.keyMap = "de";

    home-manager.users.${self.lib.username} = self.homeModules.laptop;

    # PLACEHOLDER — set this to the release actually installed on the machine.
    # See the note on this option in modules/hosts/tower/configuration.nix.
    system.stateVersion = "25.11";
  };
}
