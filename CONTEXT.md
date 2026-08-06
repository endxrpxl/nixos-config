# NixOS Configuration

A single Nix flake that builds and verifies every host in this repo, together with its dotfiles.

## Language

**Host**:
A machine this flake builds a complete NixOS system for.
_Avoid_: box, target, node

**Feature module**:
A composable slice of configuration a host opts into. A host is assembled from the feature modules it imports.
_Avoid_: profile, role, preset, package set

**Verification surface**:
The flake's checks, run as one command, that answer whether a change is valid.
_Avoid_: CI, test suite
