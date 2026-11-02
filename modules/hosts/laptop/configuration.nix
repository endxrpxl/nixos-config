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
      self.nixosModules.apps
      self.nixosModules.dev
      self.nixosModules.fingerprint
      self.nixosModules.power
      self.nixosModules.printing
      self.nixosModules.gaming
      self.nixosModules.vm
      self.nixosModules.emacs
      self.nixosModules.llms
      self.nixosModules.easyroam
    ];

    networking.hostName = "laptop";

    # The only place this host's keyboard layout is written. See
    # `console.useXkbConfig` in `base` for who reads it.
    services.xserver.xkb.layout = "de";

    # The release this host was first installed with. Never change it.
    system.stateVersion = "26.05";
  };
}
