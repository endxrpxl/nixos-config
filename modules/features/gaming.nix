{ ... }: {

  flake.nixosModules.gaming = { pkgs, ... }: {
    # Steam and much of the Proton/Wine stack ship 32-bit binaries, so the
    # 32-bit graphics drivers are a cost only a gaming host pays.
    hardware.graphics.enable32Bit = true;

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
