# The host build lives inside the verification surface

Each host's toplevel derivation is a flake check, so `nix flake check` builds the whole closure rather than only evaluating it. This makes the verification surface slow on a cold store, and that cost is the point: one command whose exit code means "this configuration evaluates, everything it depends on builds, and the Nix sources are formatted".

Evaluation was never the gap. Before this work, `nix flake check` already evaluated the flake's configuration, and passed. What was added is the build, the formatting check, and a name for the whole, not evaluation. A future reader looking for the motivation should not misremember it as "the configuration was unchecked".

## Considered Options

**Rejected: a split gate.** A fast `nix flake check` for evaluation and formatting, plus a separate explicit command for the build. Two gates means the cheap one gets run and reported as green. An agent offered a fast check and a slow one will take the fast one; so, eventually, will a human in a hurry. A single command that is sometimes slow is more honest than a fast one that proves less than its name suggests.

## Consequences

**A green check is not a working system.** This is a build gate, not a behavioral test. It proves the configuration produces a system: that every package referenced exists, that the overlays apply, that home-manager's files do not conflict. It does not prove the system boots, or that a single service starts.

**The slowness is a cold-store cost only.** A second run on an unchanged tree is served from the store and rebuilds nothing, so the expensive case is the first build after a dependency moves, not everyday use.
