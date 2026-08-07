{ ... }:
{
  # Fingerprint authentication. Assumes `desktop`: both surfaces this targets
  # — noctalia's lock screen and the noctalia greeter — belong to that module,
  # so a host importing this without it gets a daemon and nothing to use it.
  #
  # A fingerprint is an alternative to the password, never a second factor.
  # `pam_fprintd` is `sufficient` and runs before `pam_unix`, so a surface that
  # accepts a finger accepts a password too, and neither implies the other.
  #
  # This is a convenience control, not a security one: the root filesystem is
  # unencrypted, so anyone holding the machine reads it from a USB stick no
  # matter what any of this says.
  flake.nixosModules.fingerprint =
    { lib, ... }:
    {
      # `services.fprintd.enable` does not wire PAM — the fprintd module ships
      # only the daemon. PAM comes from `security.pam.services.<name>.fprintAuth`,
      # which *defaults* to `services.fprintd.enable`, so enabling the daemon
      # silently arms a fingerprint on all ~24 services at once: `su`, `passwd`,
      # `chsh`, TTY `login`, and everything else.
      #
      # That default is inverted here so the surfaces are an allowlist rather
      # than a denylist. An allowlist is the policy, readable as such; a
      # denylist grows a silent hole every time nixpkgs adds a PAM service.
      #
      # The inversion redeclares the option so its submodule gains one more
      # `config` fragment, which lands on every service at once. Mapping over
      # `config.security.pam.services` instead is the obvious spelling and is
      # infinite recursion: the names of the merged attrset would depend on a
      # definition computed from those same names.
      #
      # `mkDefault` beats the option default while still losing to the
      # per-service opt-ins, which name themselves plainly.
      options.security.pam.services = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            config.fprintAuth = lib.mkDefault false;
          }
        );
      };

      config = {
        services.fprintd.enable = true;
      };
    };
}
