# NixOS Configuration

A single Nix flake that builds and verifies every host in this repo, together with its dotfiles.

## Language

**Host**:
A machine this flake builds a complete NixOS system for. A host declares only its identity — its hardware, hostname, keyboard layout, state version, and the settings nothing but that machine can know — and imports the feature modules that supply everything else.
_Avoid_: box, target, node

**Feature module**:
A composable slice of configuration a host opts into. A host is assembled from the feature modules it imports. `base` is one of these: it holds the policy every host shares, and is a feature module rather than a special kind of thing.
_Avoid_: profile, role, preset, package set

**Shell**:
The layer a graphical session runs underneath it: bar, launcher, lock screen, greeter and theming. Distinct from the compositor and the terminal, which are true whichever shell is running. Exactly one shell is installed at a time.
_Avoid_: desktop environment, bar, panel

**Authored dotfile**:
A configuration file a human writes, linked out of the store so an edit takes effect without a rebuild. Only authored dotfiles live in `.dotfiles`. Anything a running program writes — regenerated theme snippets, settings a UI panel saves — is runtime output, is not linked, and does not belong in this repo.
_Avoid_: config, settings file

**Verification surface**:
The flake's checks, run as one command, that answer whether a change is valid.
_Avoid_: CI, test suite
