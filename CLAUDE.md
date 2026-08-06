## Verification surface

`nix flake check` is the success criterion: report work done once it exits zero. `nix fmt` fixes a formatting failure.

A cold run builds the whole desktop closure and takes a long time — that is the design, not a hang. A green check proves the configuration builds, not that the system works; see `docs/adr/0001-host-build-inside-the-verification-surface.md`.

## Agent skills

### Issue tracker

GitHub Issues on `endxrpxl/nixos-config`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, unchanged. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
