# No hibernation while a secretmem user runs

> **Live again; ADR-0007 tried to supersede this and was reverted.** Hibernation was configured and did not work on the machine, so the laptop is back to the decision below. Two corrections from that attempt stand: the attribution of the closed gate to Bitwarden is inferred, not observed (Electron is non-dumpable, so the `/proc/*/fd/*` scan recommended below cannot see its descriptors), and the "known, small diff" in *Consequences* is incomplete — it is missing `resume_offset`, without which a swapfile image is written and never found.

The laptop does not hibernate. A closed lid suspends, on battery and on mains alike; critical battery powers off. There is a 20 GiB swapfile at `/swapfile`, declared in the host's `hardware.nix`, but it is paging swap and nothing more — no `boot.resumeDevice`, no `resume_offset`, no hibernation image.

This is not a preference. The kernel refuses:

```c
bool hibernation_available(void)
{
	return nohibernate == 0 &&
		!security_locked_down(LOCKDOWN_HIBERNATION) &&
		!secretmem_active() && !cxl_mem_active();
}
```

`secretmem_active()` is true while any process holds a file created by `memfd_secret(2)`, and the count is incremented when the file is created, not when it is mapped. Bitwarden holds one from autostart, with the vault still locked. So `/sys/power/disk` reads `[disabled]` in every session, `/sys/power/state` omits `disk`, and logind reports `CanHibernate = na`.

The kernel is right to refuse. Secret memory exists so that a key is unreadable outside the process that owns it; hibernating would write it to disk in the clear. On this machine the root filesystem is unencrypted, so that image would sit in plaintext next to everything else — exactly the exposure the password manager is avoiding.

## Considered Options

**Rejected: keep hibernation configured and let it fail.** This was the state that revealed the problem, and it is worse than it sounds. **logind does not fall back when a configured action is unavailable** — it logs "operation not supported" and does nothing. So `HandleLidSwitch = "suspend-then-hibernate"` did not degrade to suspending; it made the lid a no-op, and a laptop closed on battery stayed awake in a bag. `criticalPowerAction = "Hibernate"` was inert in the same way, which is the original fault this work set out to fix: an action the machine cannot perform is indistinguishable from no action at all.

**Rejected: drop Bitwarden's autostart.** Hibernation would work in sessions where Bitwarden was never opened. But lid and critical-battery actions are static configuration evaluated at build time, while `hibernation_available()` is a runtime property of whichever processes happen to be alive. The configuration would be correct or a silent no-op depending on whether a password manager was open — the same trap as above, now intermittent and much harder to notice.

**Rejected: `criticalPowerAction = "HybridSleep"`,** the upstream default and what this host shipped with. Doubly wrong: it needs the hibernation that is unavailable, and it is a lid strategy rather than a critical-battery one, keeping a RAM copy alive on a cell that is about to die.

**Rejected: TLP.** Not a hibernation decision, but the reason the `power` module exists and worth recording where it will be found. TLP supplies the battery charge thresholds the module was created for, in two lines. It also applies its entire default policy — disk APM, USB autosuspend, wifi power save, governor, runtime PM — and then contends with `power-profiles-daemon` over the governor, EPP and platform profile on every AC transition, which would break noctalia's power-profile widget. Current nixpkgs asserts only against `services.tlp.pd`, so `services.tlp.enable = true` alongside `power-profiles-daemon` evaluates green and fights at runtime: a case the verification surface cannot catch. Two sysfs writes were what was actually wanted.

## Consequences

**Powering off at critical battery loses unsaved work, and remains correct.** The alternative was never hibernation; it was running the cell flat and losing the same work with a deep discharge on top.

**A closed lid on battery drains slowly rather than not at all.** Suspend-to-idle is what this machine offers — `/sys/power/state` is `freeze mem`, with no S3 — so a laptop left shut for several days will be flat. That was the specific loss taken here, and the reason hibernation was wanted.

**`nix flake check` could not have caught any of this.** It proved the module evaluated, and it evaluated identically whether or not the kernel would accept a single one of the verbs in it. Hibernation was configured, green, and impossible at the same time. The check is a statement about the configuration, never about the machine — the point ADR-0001 makes about host builds, here with teeth.

**Restoring hibernation is a known, small diff, and needs one thing that is not in this repo.** Put back `boot.resumeDevice` with the root UUID from `_hardware-generated.nix`, set the lid to `suspend-then-hibernate` with a `HibernateDelaySec`, and set `criticalPowerAction = "Hibernate"`. None of it works until nothing on the system holds a `memfd_secret` — check with `cat /sys/power/disk` before trusting it, and find the holder with a scan of `/proc/*/fd/*` for `secretmem`. Encrypting the root filesystem would remove the objection in principle but not the kernel's gate, which does not ask whether the disk is encrypted.

**The swapfile stays at 20 GiB** even though nothing now needs it to hold a 16 GiB image. It is already allocated, it is the right size if hibernation ever returns, and shrinking it reclaims ~5% of free space on a disk with 400 GB spare.

**`nixos-generate-config` will never emit this swapfile.** It reads `/proc/swaps` and emits only entries of type `partition`, skipping `file` on the stated grounds that swap files are declared by hand. `_hardware-generated.nix` therefore keeps printing `swapDevices = [ ]` however the machine is running when `regen-hardware` is invoked. `swapDevices` is a list option, so the two definitions concatenate rather than conflict, and a rescan cannot eat the hand-written one.
