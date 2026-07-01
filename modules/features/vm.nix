{ ... }: {
  flake.nixosModules.vm = { pkgs, ... }: {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
    };

    environment.systemPackages = [ pkgs.distrobox ];
  };
}
