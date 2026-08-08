{ ... }: {
  flake.nixosModules.llms = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      pi-coding-agent
      opencode
    ];
  };
}
