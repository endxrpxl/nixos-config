{ ... }: {

  flake.nixosModules.gaming = { pkgs, ... }: {
    programs.gamemode.enable = true;

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    programs.gamescope.enable = true;

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
