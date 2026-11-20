## NixOS Configuration

A single Nix flake that builds every host in this repo, together with its
dotfiles.

| Host     | Machine                     |
| -------- | --------------------------- |
| `tower`  | Desktop, dual-boots Windows |
| `laptop` | ThinkPad T14 Gen 3 (Intel)  |

See [INSTALL.md](INSTALL.md) to install a host on a new machine or apply this
config to an existing NixOS install, or [INSTALL-SSH.md](INSTALL-SSH.md) to run
the fresh install over SSH from another machine.

## Layout

`modules/` loads entirely through import-tree, and each file there is a
flake-parts module.

- `modules/features/` holds one file per feature. Each file defines a NixOS
  module and, where it needs one, a home-manager half that the NixOS half
  imports itself.
- `modules/hosts/<host>/` holds the host's identity (`configuration.nix`) and
  its hardware (`hardware.nix` and the generated scan).
- `modules/lib/` holds shared constants and helpers, exposed as `self.lib`.

`.dotfiles/` holds hand-edited config. Most programs have a shared file plus a
`hosts/<hostname>` file, and home-manager links the right host file by hostname.

The links point out of the Nix store into this checkout, so an edit takes effect
without a rebuild. That needs the repo at `~/nixos-config`.

Files that programs write at runtime are not linked. EasyEffects is the
exception. It writes its settings through the links, so changes made in its GUI
show up as diffs in this repo, ready to commit.

umbriel is the compositor. noctalia is the shell and the greeter.

## Day to day

```bash
nix flake check          # evaluate every host and check formatting
nix fmt                  # fix formatting
nh os switch             # build and activate this machine's host
nix flake update         # bump inputs, then re-check
sudo nix run .#regen-hardware   # re-scan this machine's hardware
```

Each host's `_hardware-generated.nix` holds the hardware scan. The command above
rewrites it, and nobody edits it by hand. Hand-written hardware settings go in
the host's `hardware.nix`. The scan is committed rather than read from
`/etc/nixos`, so every host evaluates under `nix flake check` on any machine.
