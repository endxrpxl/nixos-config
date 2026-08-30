{ ... }:
{
  # Fingerprint authentication. Assumes `desktop`: every authentication surface
  # this targets is noctalia's, so a host importing this without it gets a
  # daemon and nothing to use it.
  #
  # Two surfaces are wired up: the lock screen and polkit prompts. The lock
  # screen needs nothing from PAM. noctalia 5 talks to fprintd over D-Bus
  # directly, so the whole of that surface is `services.fprintd.enable` plus
  # one key in the host's noctalia dotfile.
  #
  # A fingerprint is an alternative to the password, never a second factor.
  # `pam_fprintd` is `sufficient` and runs before `pam_unix`, so any surface
  # opted in below accepts a password too.
  #
  # This is a convenience control, not a security one: a fingerprint produces
  # no key material, so it can never unlock at-rest protection and only ever
  # acts on surfaces the machine is already running with the disk open. The
  # decryption gate is the line that keeps it off the boot prompt.
  #
  # Which surfaces are opted in, and why the greeter is not among them.
  flake.nixosModules.fingerprint =
    { lib, ... }:
    {
      # `services.fprintd.enable` does not wire PAM. The fprintd module ships
      # only the daemon. PAM comes from `security.pam.services.<name>.fprintAuth`,
      # which *defaults* to `services.fprintd.enable`, so switching the daemon on
      # would otherwise arm a fingerprint across every PAM service at once: `su`,
      # `passwd`, `chsh`, TTY `login`, and everything else.
      #
      # Inverting that default makes the surfaces an allowlist rather than a
      # denylist. An allowlist is the policy, readable as such; a denylist grows
      # a silent hole every time nixpkgs adds a PAM service.
      #
      # The inversion redeclares the option so its submodule gains one more
      # `config` fragment, which lands on every service at once. Mapping over
      # `config.security.pam.services` instead is the obvious spelling and is
      # infinite recursion: the names of the merged attrset would depend on a
      # definition computed from those same names.
      #
      # `mkDefault` beats the option default while still losing to the
      # per-surface opt-ins, which name themselves plainly.
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
