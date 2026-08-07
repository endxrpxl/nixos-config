{ ... }:
{
  # Fingerprint authentication. Assumes `desktop`: every authentication surface
  # this targets is noctalia's, so a host importing this without it gets a
  # daemon and nothing to use it.
  #
  # Two surfaces are wired up: the lock screen and polkit prompts. The lock
  # screen needs nothing from PAM — noctalia 5 talks to fprintd over D-Bus
  # directly — so the whole of that surface is `services.fprintd.enable` plus
  # one key in the host's noctalia dotfile.
  #
  # The greeter is left out, and cannot be added on its own terms: see the note
  # on `greetd` below. Its fingerprint is available only by giving `login` one,
  # which is a trade this host has not made.
  #
  # A fingerprint is an alternative to the password, never a second factor.
  # `pam_fprintd` is `sufficient` and runs before `pam_unix`, so any surface
  # opted in below accepts a password too.
  #
  # This is a convenience control, not a security one: the root filesystem is
  # unencrypted, so anyone holding the machine reads it from a USB stick no
  # matter what any of this says.
  flake.nixosModules.fingerprint =
    { lib, ... }:
    {
      # `services.fprintd.enable` does not wire PAM — the fprintd module ships
      # only the daemon. PAM comes from `security.pam.services.<name>.fprintAuth`,
      # which *defaults* to `services.fprintd.enable`, so switching the daemon on
      # would otherwise arm a fingerprint across every PAM service at once: `su`,
      # `passwd`, `chsh`, TTY `login`, and everything else.
      #
      # So this is load-bearing right now, not groundwork for the surfaces added
      # later: it is what stops the line below from handing `sudo` a fingerprint
      # prompt today. With nothing opted in, the built system generates no
      # `pam_fprintd` rules at all.
      #
      # Inverting the default makes the surfaces an allowlist rather than a
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

        # The one PAM surface. `login` is deliberately absent: the lock screen
        # does not reach PAM for a fingerprint, and `login` is also what agetty
        # uses, so opting it in would put a blocking sensor prompt in front of
        # every TTY login — the same reason `sudo` is not here.
        #
        # `greetd` is absent for a less obvious reason. Setting `fprintAuth` on
        # it does nothing at all: the greetd module sets `useDefaultRules =
        # false` and replaces its whole auth stack with `auth substack login`,
        # and `fprintAuth` only ever acts through those default rules. The
        # greeter authenticates against `login`'s stack, so the greeter cannot
        # have a fingerprint unless TTY login does too.
        security.pam.services.polkit-1.fprintAuth = true;
      };
    };
}
