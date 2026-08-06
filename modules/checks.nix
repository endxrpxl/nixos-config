{ self, lib, ... }:
{
  # Build every NixOS host that targets the system being checked. Check names
  # are prefixed so a host build is distinguishable at a glance from the other
  # checks in the flake, such as formatting.
  perSystem =
    { system, ... }:
    let
      hostsForSystem = lib.filterAttrs (
        # Read the instantiated pkgs rather than `config.nixpkgs.hostPlatform`:
        # a host declared via `nixosSystem { system = ...; }` sets the legacy
        # `nixpkgs.system` instead, and reading hostPlatform there throws.
        _: nixos: nixos.pkgs.stdenv.hostPlatform.system == system
      ) self.nixosConfigurations;
    in
    {
      checks = lib.mapAttrs' (
        name: nixos: lib.nameValuePair "nixos-${name}" nixos.config.system.build.toplevel
      ) hostsForSystem;
    };
}
