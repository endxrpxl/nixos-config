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

    # PLACEHOLDER — the XKB name for the same unconfirmed layout, for the login
    # screen. Keep in step with console.keyMap above and with
    # .dotfiles/.config/niri/hosts/laptop.kdl.
    programs.noctalia-greeter.settings.keyboard.layout = "de";

    home-manager.users.${self.lib.username} = self.homeModules.laptop;

    # PLACEHOLDER — this must become the NixOS release the machine is actually
    # first installed from, and then never change. It determines the defaults
    # for stateful data such as file locations and database versions.
    system.stateVersion = "25.11";
  };
}
