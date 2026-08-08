# Fingerprint surfaces are an allowlist

The `fingerprint` module enables `fprintd` and then opts individual authentication surfaces in by name. Two are opted in: the lock screen, which needs no PAM at all because noctalia 5 talks to fprintd over D-Bus directly, and polkit prompts, which get `security.pam.services.polkit-1.fprintAuth = true`. Everything else — `login`, `sudo`, `su`, `passwd`, `chsh`, the greeter — is not.

The allowlist is not the NixOS default, and making it one is the module's only non-obvious piece of code. `security.pam.services.<name>.fprintAuth` *defaults* to `services.fprintd.enable`, so switching the daemon on arms a fingerprint across every PAM service at once. The module redeclares the option with `config.fprintAuth = lib.mkDefault false` so the submodule gains one more `config` fragment, which lands on every service; `mkDefault` still loses to the per-surface opt-ins, so those read as plain assignments.

A fingerprint here is an alternative to the password, never a second factor: `pam_fprintd` is `sufficient` and runs before `pam_unix`, so every opted-in surface still accepts a password. And this is a convenience control rather than a security one — the root filesystem is unencrypted, so anyone holding the machine reads it from a USB stick regardless.

## Considered Options

**Rejected: a denylist.** Leave the upstream default alone and switch off the surfaces that should not have a fingerprint. This is one line shorter today and grows a silent hole every time nixpkgs adds a PAM service. An allowlist is the policy, and reads as the policy.

**Rejected: mapping over `config.security.pam.services`.** The obvious spelling of "set this on every service" is infinite recursion: the names of the merged attrset would depend on a definition computed from those same names. Redeclaring the option's submodule type is what works.

**Rejected: `login`.** The lock screen does not reach PAM for a fingerprint, so opting `login` in buys nothing there — and `login` is also what agetty uses, so it would put a blocking sensor prompt in front of every TTY login. Same reason `sudo` is absent.

**Rejected: the greeter.** This one was built, worked, and was reverted, and the obstacle is not fingerprints at all.

`fprintAuth` on `greetd` is inert to begin with: the greetd module sets `useDefaultRules = false` and replaces the whole auth stack with `auth substack login`, and `fprintAuth` acts only through the default rules that disables. Adding a `pam_fprintd` rule to greetd's own stack ahead of the substack does work, and leaves `login` untouched so TTY logins keep their password.

What kills it is the keyring. `pam_gnome_keyring` sits inside the `login` substack and unlocks the keyring with the password `pam_unix` just took. A `sufficient` fingerprint rule short-circuits PAM before the substack runs, so neither module ever sees a password — and the keyring is encrypted with that password, so a fingerprint cannot derive its key even in principle. Logging in with a finger therefore lands in a session that immediately asks for the password anyway, which is worse than typing it once. The ways round it blank the keyring password or store it on disk, and both give away more than the keystroke they save.

## Consequences

**The lock screen is where a fingerprint is actually worth having.** By the time it appears the session's keyring is already unlocked, which is exactly what the greeter cannot assume. That asymmetry is the whole reason one surface is in and the other is out.

**Enrolment is not declarative.** `fprintd-enroll` has to be run on the machine; see the README. A host can build this module green and have no fingerprint stored.

**Adding a surface is one line, and should be argued here first.** The allowlist makes the addition trivial to write, which is precisely why the reasoning belongs in this document rather than in the diff.
