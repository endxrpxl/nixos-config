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
    { config, lib, ... }:
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
        security.pam.services.polkit-1.fprintAuth = true;

        # The greeter cannot use `fprintAuth`, and setting it would silently do
        # nothing: the greetd module sets `useDefaultRules = false` and replaces
        # greetd's whole auth stack with `auth substack login`, while
        # `fprintAuth` only ever acts through the default rules that disables.
        #
        # Following the substack to its source and giving `login` the
        # fingerprint would work, but arms every TTY login with it too — the
        # blocking sensor prompt this host rejected when it left out `sudo` —
        # and would put `pam_fprintd` in the stack noctalia's lock screen uses
        # for its *password* path, where it would contend with the shell's own
        # D-Bus grab of the same sensor.
        #
        # So the rule is added to greetd's own stack instead, ahead of the
        # substack, leaving `login` untouched. Restoring `useDefaultRules` is
        # the other way to do this and is not worth it: that option is marked
        # experimental and "subject to breaking changes without notice", and
        # flipping it would regenerate the account, password and session stacks
        # alongside the substacks that already cover them.
        #
        # The order is relative because the built-in values are documented as
        # liable to change; a constant here could silently reorder into the
        # wrong place on an update.
        security.pam.services.greetd.rules.auth.fprintd = {
          enable = true;
          control = "sufficient";
          modulePath = "${config.services.fprintd.package}/lib/security/pam_fprintd.so";
          order = config.security.pam.services.greetd.rules.auth.login.order - 10;
        };

        # The greeter refuses to start PAM at all while its password box is
        # empty, which leaves the rule above unreachable: PAM is what asks for
        # the finger, so something has to start it. This is upstream's switch
        # for exactly that, described in its own config template as enabling
        # "fprintd / smartcard PAM" auth.
        #
        # It weakens nothing by itself — an empty submission still has to
        # satisfy PAM, and `pam_unix` rejects an empty password.
        #
        # This reaches into `desktop`'s option, which is why this module says
        # up front that it assumes `desktop`.
        programs.noctalia-greeter.settings.auth.allow_empty_password = true;
      };
    };
}
