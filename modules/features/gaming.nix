{ ... }: {

  flake.nixosModules.gaming = { config, pkgs, ... }: {
    programs.gamemode.enable = true;

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    programs.gamescope.enable = true;

    nixpkgs.overlays = [
      (final: prev: {
        openldap = prev.openldap.overrideAttrs (_: {
          doCheck = false;
        });
      })
    ];

    environment.systemPackages = with pkgs; [
      heroic
      bottles
      protonup-qt
      mangohud
      prismlauncher
      lutris
    ];
  };
}
