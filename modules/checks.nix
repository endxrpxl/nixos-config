{ self, lib, ... }:
{
  # Build every NixOS host that targets the system being checked. Hosts are
  # discovered rather than listed, so a new host enters the verification
  # surface the moment it is declared, with no change here.
  #
  # The prefix once disambiguated a `desktop` host from a `desktop` feature
  # module; that collision is gone since the host was renamed to `tower`. It
  # stays because it still separates a host build from the flake's other
  # checks, such as formatting.
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
