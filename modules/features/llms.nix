{ inputs, ... }: {
  flake.nixosModules.llms = { pkgs, ... }: {
    environment.systemPackages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
      omp
    ];
  };
}
