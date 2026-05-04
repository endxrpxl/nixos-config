{ ... }: {

  flake.nixosModules.gaming = { config, pkgs, ... }: {
    programs.gamemode.enable = true;

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    environment.systemPackages = with pkgs; [
      heroic
      # bottles
      protonup-qt
      mangohud
      prismlauncher
    ];
  };
}