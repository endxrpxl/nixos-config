## NixOS Configuration

A single Nix flake that builds every host in this repo, together with its
dotfiles.

| Host     | Machine                     |
| -------- | --------------------------- |
| `tower`  | Desktop, dual-boots Windows |
| `laptop` | ThinkPad T14 Gen 3 (Intel)  |

See [INSTALL.md](INSTALL.md) to install a host on a new machine or apply this
config to an existing NixOS install.

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
