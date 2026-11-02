{ inputs, ... }:
{
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem = {
    treefmt = {
      projectRootFile = "flake.nix";
      programs.nixfmt.enable = true;

      # Unused bindings. `nix fmt` removes them, and `nix flake check` fails
      # while any remain. The hardware scans are left alone: their unused
      # arguments come from nixos-generate-config, and the next scan would
      # write them back.
      programs.deadnix.enable = true;
      settings.formatter.deadnix.excludes = [ "modules/hosts/*/_hardware-generated.nix" ];
    };
  };
}
