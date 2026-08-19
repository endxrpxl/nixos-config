{ inputs, ... }: {
  flake.nixosModules.llms = { pkgs, ... }: {
    imports = [ inputs.omp.nixosModules.default ];

    programs.omp.enable = true;

    environment.systemPackages = with pkgs; [
      pi-coding-agent
      opencode
    ];
  };
}
