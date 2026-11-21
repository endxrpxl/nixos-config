{ self, inputs, ... }: {

  flake.nixosConfigurations.blue = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.blue
    ];
  };

  # Identity only. Everything machine-agnostic lives in `base`; everything
  # optional lives in the feature module that owns it.
  flake.nixosModules.blue = { ... }: {
    imports = [
      self.nixosModules.blueHardware
      self.nixosModules.base
      self.nixosModules.desktop
      self.nixosModules.apps
      self.nixosModules.dev
      self.nixosModules.printing
      self.nixosModules.gaming
      self.nixosModules.vm
      self.nixosModules.emacs
      self.nixosModules.llms
    ];

    networking.hostName = "blue";

    services.xserver.xkb = {
      layout = "us";
    };

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "26.05"; # Did you read the comment?
  };
}
