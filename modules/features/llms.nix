{ ... }: {
  flake.nixosModules.llms = { pkgs, ... }: {

    environment.systemPackages = with pkgs; [
      opencode
      code-cursor
    ];
  };
}
