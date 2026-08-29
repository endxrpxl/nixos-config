# Hibernate to the swapfile

> **Reverted. ADR-0006 stands.** This decision was an experiment with a stated exit test: configure hibernation, then read `/sys/power/disk` on the machine. The machine failed it. Everything it added is gone: `boot.resumeDevice`, `resume_offset`, `check-resume-offset.service`, the `suspend-then-hibernate` lid and `criticalPowerAction = "Hibernate"`. The laptop suspends on battery and on mains, and critical battery powers off, exactly as ADR-0006 describes.
>
> The document is kept because the experiment produced findings that outlive it, and the next person to reach for hibernation on this host will want them: the two corrections to ADR-0006 below, and the two alternatives in *Considered Options* that were rejected on scope rather than merit.

What follows is the decision as it was written. It is no longer in force.

Two things changed, and only one of them is a decision.

## The secretmem gate was inferred, not observed

ADR-0006 rests on `hibernation_available()` returning false because Bitwarden holds a `memfd_secret`. The observable half of that is solid and still reproduces: `/sys/power/disk` reads `[disabled]`, `/sys/power/state` is `freeze mem`. The attribution to Bitwarden is weaker than it reads. It was never confirmed against a live process:

- Electron marks itself non-dumpable, so `/proc/<pid>/fd` is `Permission denied` for the *owning user*, not just for other users. The `/proc/*/fd/*` scan ADR-0006 recommends cannot see Bitwarden's descriptors at all.
- This kernel exports no `Secretmem:` line in `/proc/meminfo`, so there is no global counter to check either.
- `secretmem_active()` is one of four terms. `nohibernate`, `security_locked_down(LOCKDOWN_HIBERNATION)` and `cxl_mem_active()` produce exactly the same `[disabled]`, and none was ruled out.

So the gate is closed and the reason is a hypothesis. That is not a claim ADR-0006 is wrong. It may well be right. But it is a thinner basis than a rejected design deserves, and the way to settle it is to configure hibernation and watch the machine, which is what this decision does.

## The restore ADR-0006 described could not have worked

ADR-0006 calls the way back "a known, small diff": put back `boot.resumeDevice`, set the lid to `suspend-then-hibernate`, set `criticalPowerAction = "Hibernate"`. That diff is incomplete, and the missing piece is not about the gate at all.

Root is ext4 and swap is a *file*. `resume=` names the block device holding the filesystem; the kernel still has to be told where in that device the swapfile physically starts, via `resume_offset=`. The command line of the generation ADR-0006 was written against carries `resume=/dev/disk/by-uuid/7003dde5-…` and no `resume_offset`. That configuration would have written an image on suspend and failed to find it on resume, every time. A second fault, hidden behind the first, and it would have been blamed on the first.

`resume_offset` is therefore part of this decision, in `hardware.nix` beside the swapfile that determines it.

## Considered Options

**Rejected: leave it alone until the gate is proven open.** The gate cannot be proven open from a session in which it is closed, and the thing that would open it, closing Bitwarden, is a runtime act with no configuration to test. Configuring hibernation and reading `/sys/power/disk` is the experiment; ADR-0006 already established there is no way to ask this question at build time.

**Rejected: drop Bitwarden's autostart.** Still rejected, and for ADR-0006's reason unchanged: lid and critical-battery actions are static configuration, `hibernation_available()` is a runtime property, and making the former correct only when a particular app is closed is the same trap intermittently. It is also the wrong order of business while the attribution to Bitwarden is unconfirmed.

**Rejected: `boot.initrd.systemd.enable = true` instead of `resume_offset`.** systemd writes a `HibernateLocation` EFI variable at hibernate time carrying the device *and* the offset, and `systemd-hibernate-resume` in a systemd initrd reads it. No kernel parameter, no offset to keep in sync. Genuinely the better mechanism, and rejected here only as scope: it replaces this host's whole stage-1 for a change that is otherwise two lines and a guard. Worth revisiting on its own.

**Rejected: hardcoding `resume_offset` and trusting it.** `mkswap-swapfile.service` recreates `/swapfile` if it is ever absent, and the new file lands wherever ext4 puts it. A stale offset does not fail loudly. The kernel finds no image signature and boots normally, so hibernation degrades to "the machine forgot", which is indistinguishable from a crash. `check-resume-offset.service` compares the configured number against `filefrag` on every boot and fails the unit if they have parted company, in the same spirit as the charge-threshold unit's bare redirect.

## Consequences

**The gate was still closed, and the lid was a no-op again.** This was the anticipated failure, entered deliberately, and it is what happened: logind does not fall back, so `suspend-then-hibernate` on a machine that cannot hibernate is a laptop left awake in a bag. That is why the revert is a revert and not a smaller adjustment. There is no version of these settings that degrades gracefully. Which of the four terms of `hibernation_available()` holds the gate shut is still unknown; the experiment settled that hibernation does not work here, not why.

**A hibernation image would have been RAM in the clear on an unencrypted root.** ADR-0006 raises this as the reason the kernel's refusal is *correct*, and it never stopped applying: `/swapfile` sits on an unencrypted ext4 root, so everything in memory at hibernate time, keys, unlocked vault contents, whatever a browser was holding, would be readable by anyone with the disk. This was accepted as the price of a feature that turned out not to exist. Encrypting the root filesystem would remove the objection but not the kernel's gate, which does not ask whether the disk is encrypted.

**The swapfile stays at 20 GiB**, for ADR-0006's reasons unchanged: already allocated, right-sized if hibernation ever becomes possible, and worth ~5% of free space on a disk with 400 GB spare.

**`nix flake check` said nothing about any of this.** The check proved these options evaluate, and they did, green while the kernel refused every verb in them. ADR-0001's point, for the third time, and the reason this was framed as an experiment to run on the machine rather than a change to merge on a passing build.
