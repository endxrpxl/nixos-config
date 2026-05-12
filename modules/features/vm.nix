{ self, inputs, ... }: {
  flake.nixosModules.vm = { config, pkgs, ... }: {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
    };

    environment.systemPackages = [ pkgs.distrobox ];
  };
}