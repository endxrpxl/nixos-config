## Verification surface

`nix flake check` is the success criterion: report work done once it exits zero. `nix fmt` fixes a formatting failure.

A cold run builds every host's whole closure and takes a long time. That is the design, not a hang. A green check proves the configuration builds, not that the system works; see `docs/adr/0001-host-build-inside-the-verification-surface.md`. Both hosts now describe real machines; `docs/adr/0003-placeholder-host-in-the-verification-surface.md` records the period when `laptop` did not.

A new file under `.dotfiles` must be `git add`ed before `nix flake check` will see it. Dotfile paths are asserted against the flake source at eval time, and an untracked file is not part of that source. The check fails with `authored dotfile '...' does not exist` for a file that is plainly on disk.

## Agent skills

### Issue tracker

GitHub Issues on `endxrpxl/nixos-config`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, unchanged. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
