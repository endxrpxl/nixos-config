# A placeholder host may sit inside the verification surface

The `laptop` host was added before the machine existed. Its filesystem UUIDs and console keymap are not real values, so it builds green and cannot boot. This qualifies ADR 0001: a green `nix flake check` proves this configuration evaluates and builds, and for `laptop` it currently proves nothing whatsoever about the machine.

The alternative was to keep the laptop out of `nixosConfigurations` until real hardware arrived. That was rejected because the `base` extraction in ADR 0002 depends on a second host proving it — a seam with one consumer is a guess, and an unbuilt second host verifies nothing. Admitting the placeholder is what makes the extraction real work rather than speculation.

## Consequences

**The placeholder is loud, not silent.** The UUIDs are all-zero rather than plausible, so they can never accidentally match a disk and a mistaken deploy fails at mount time instead of touching an unintended filesystem. The host also emits a `warnings` entry, so every `nixos-rebuild` and every evaluation prints that it is a placeholder. A green check that would otherwise quietly overstate itself says so out loud instead.

**Clearing it is one commit.** Paste the real values from `nixos-generate-config`, set the real keymap and state version, delete the warning. The warning text lists exactly these steps.

**This is not a licence for more placeholders.** The practice is sound only because the fake values are unmistakable, self-announcing, and short-lived. A placeholder that outlives the wait for hardware, or one whose values look real, degrades the signal ADR 0001 rests on.
