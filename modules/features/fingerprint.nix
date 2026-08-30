{ ... }: {
  flake.nixosModules.fingerprint = { lib, ... }:
  {
    options.security.pam.services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          config.fprintAuth = lib.mkDefault false;
        }
      );
    };

    config = {
      services.fprintd.enable = true;

      # The one PAM surface. Everything else (`login`, `sudo`, the greeter)
      # is left on the `mkDefault false` above.
      security.pam.services.polkit-1.fprintAuth = true;
    };
  };
}
