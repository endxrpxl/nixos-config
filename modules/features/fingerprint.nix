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
  # The greeter is left out, and the reason is the gnome-keyring rather than
  # anything about fingerprints. It was wired up, worked, and was reverted: see
  # the note on `greetd` below.
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
        # `greetd` is absent for a reason worth writing down, because the
        # mechanism works and the obstacle is somewhere else entirely.
        #
        # `fprintAuth` on `greetd` is inert to begin with: the greetd module
        # sets `useDefaultRules = false` and replaces the whole auth stack with
        # `auth substack login`, and `fprintAuth` acts only through the default
        # rules that disables. Adding a `pam_fprintd` rule to greetd's own
        # stack ahead of the substack does work, and leaves `login` untouched
        # so TTY logins keep their password.
        #
        # What kills it is the keyring. `pam_gnome_keyring` sits inside the
        # `login` substack, and unlocks the keyring with the password
        # `pam_unix` just took. A `sufficient` fingerprint rule short-circuits
        # PAM before the substack runs, so neither module ever sees a password
        # — and the keyring is encrypted with that password, so a fingerprint
        # cannot derive its key even in principle. Logging in with a finger
        # therefore lands in a session that immediately asks for the password
        # anyway, which is worse than typing it once. The only ways round it
        # blank the keyring password or store it on disk, and both give away
        # more than the keystroke they save.
        #
        # None of this touches the lock screen: the session's keyring is
        # already unlocked by then, which is why a finger is worth having there
        # and not here.
        security.pam.services.polkit-1.fprintAuth = true;
      };
    };
}
