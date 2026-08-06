{ ... }: {

  flake.nixosModules.gaming = { pkgs, ... }: {
    # Steam and much of the Proton/Wine stack ship 32-bit binaries, so the
    # 32-bit graphics and audio paths are a cost only a gaming host pays.
    # `enable` is declared here too rather than depended on from `desktop`:
    # this module should stand up on its own, and `enable = true` merges, so
    # a second declaration is not a conflict.
    hardware.graphics.enable = true;
    hardware.graphics.enable32Bit = true;
    services.pipewire.alsa.support32Bit = true;

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
