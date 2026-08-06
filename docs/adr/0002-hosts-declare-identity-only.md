# Hosts declare identity only

A host declares only what nothing else can know — its hardware, hostname, keyboard layout, state version, and the boot entries specific to that machine — and imports feature modules for everything else. Shared policy lives in `base`, an ordinary feature module every host imports. Before this, the single host's `configuration.nix` was 150 lines of which roughly five were actually about that machine.

The `desktop` host was renamed to `tower` as part of this. `desktop` named two different things: a machine and the graphical-environment feature module. That was tolerable with one host and actively misleading with two, because the laptop is not a desktop yet imports the `desktop` feature. Host names are now role-shaped (`tower`, `laptop`) and survive hardware replacement, and `desktop` unambiguously means the feature. This also freed the awkward `desktopConfiguration` / `desktopHardware` module names, which existed only to dodge the collision.

## Considered Options

**Rejected: `base` as a new kind of module.** An implicitly-applied module that a host cannot forget would buy safety against a mistake that two hosts and `nix flake check` catch immediately. Making `base` an ordinary feature module keeps the vocabulary at one concept instead of two, and the "every host imports it" property is a convention the checks enforce by building.

**Rejected: `base` declaring its own options.** Hosts could have set `my.base.keymap` and similar. That invents a configuration language on top of one that already has this feature. When a host needs to diverge on something `base` declares, the fix is `mkDefault` in `base`, not a new option — an option added before a second consumer exists is a guess about where the seam falls.

**Rejected: no `base` at all.** Pushing every setting down into the feature module that owns it is the purist answer, and it is where `hardware.graphics.enable32Bit` went — it existed only for Steam, so it belongs to `gaming`. But `nix.gc`, the locale block, and the shared package set have no honest feature owner, so this would have produced a `base` anyway plus a scattering.

## Consequences

**The seam was cut against a real second host, not a predicted one.** The laptop was added as a full copy of the tower first and both were proven to build; only then was the duplication deleted into `base`. The line falls where the two configurations actually differ.

**A setting earns a place in `base` only if varying it per host would be a bug rather than a preference.** By that test three settings left the shared module: `enable32Bit` to `gaming`, and `hardwareClockInLocalTime` and `console.keyMap` to the hosts.

**Home-manager modules are keyed by host, not by username.** `homeModules.${username}` collided with `homeModules.desktop`, the feature. There is still exactly one human, so `self.lib.username` remains a flake-wide constant and the path constants derived from it are unchanged.
