# Hibernate to the swapfile

Supersedes ADR-0006. The laptop hibernates again: a closed lid on battery suspends and then hibernates after 30 minutes, critical battery hibernates rather than powering off, and the 20 GiB `/swapfile` that ADR-0006 kept "in case hibernation ever becomes possible" now holds the image.

Two things changed, and only one of them is a decision.

## The secretmem gate was inferred, not observed

ADR-0006 rests on `hibernation_available()` returning false because Bitwarden holds a `memfd_secret`. The observable half of that is solid and still reproduces: `/sys/power/disk` reads `[disabled]`, `/sys/power/state` is `freeze mem`. The attribution to Bitwarden is weaker than it reads. It was never confirmed against a live process:

- Electron marks itself non-dumpable, so `/proc/<pid>/fd` is `Permission denied` for the *owning user*, not just for other users. The `/proc/*/fd/*` scan ADR-0006 recommends cannot see Bitwarden's descriptors at all.
- This kernel exports no `Secretmem:` line in `/proc/meminfo`, so there is no global counter to check either.
- `secretmem_active()` is one of four terms. `nohibernate`, `security_locked_down(LOCKDOWN_HIBERNATION)` and `cxl_mem_active()` produce exactly the same `[disabled]`, and none was ruled out.

So the gate is closed and the reason is a hypothesis. That is not a claim ADR-0006 is wrong — it may well be right — but it is a thinner basis than a rejected design deserves, and the way to settle it is to configure hibernation and watch the machine, which is what this decision does.

## The restore ADR-0006 described could not have worked

ADR-0006 calls the way back "a known, small diff": put back `boot.resumeDevice`, set the lid to `suspend-then-hibernate`, set `criticalPowerAction = "Hibernate"`. That diff is incomplete, and the missing piece is not about the gate at all.

Root is ext4 and swap is a *file*. `resume=` names the block device holding the filesystem; the kernel still has to be told where in that device the swapfile physically starts, via `resume_offset=`. The command line of the generation ADR-0006 was written against carries `resume=/dev/disk/by-uuid/7003dde5-…` and no `resume_offset` — so that configuration would have written an image on suspend and failed to find it on resume, every time. A second fault, hidden behind the first, and it would have been blamed on the first.

`resume_offset` is therefore part of this decision, in `hardware.nix` beside the swapfile that determines it.

## Considered Options

**Rejected: leave it alone until the gate is proven open.** The gate cannot be proven open from a session in which it is closed, and the thing that would open it — closing Bitwarden — is a runtime act with no configuration to test. Configuring hibernation and reading `/sys/power/disk` is the experiment; ADR-0006 already established there is no way to ask this question at build time.

**Rejected: drop Bitwarden's autostart.** Still rejected, and for ADR-0006's reason unchanged: lid and critical-battery actions are static configuration, `hibernation_available()` is a runtime property, and making the former correct only when a particular app is closed is the same trap intermittently. It is also the wrong order of business while the attribution to Bitwarden is unconfirmed.

**Rejected: `boot.initrd.systemd.enable = true` instead of `resume_offset`.** systemd writes a `HibernateLocation` EFI variable at hibernate time carrying the device *and* the offset, and `systemd-hibernate-resume` in a systemd initrd reads it — no kernel parameter, no offset to keep in sync. Genuinely the better mechanism, and rejected here only as scope: it replaces this host's whole stage-1 for a change that is otherwise two lines and a guard. Worth revisiting on its own.

**Rejected: hardcoding `resume_offset` and trusting it.** `mkswap-swapfile.service` recreates `/swapfile` if it is ever absent, and the new file lands wherever ext4 puts it. A stale offset does not fail loudly — the kernel finds no image signature and boots normally, so hibernation degrades to "the machine forgot", which is indistinguishable from a crash. `check-resume-offset.service` compares the configured number against `filefrag` on every boot and fails the unit if they have parted company, in the same spirit as the charge-threshold unit's bare redirect.

## Consequences

**If the gate is still closed, the lid is a no-op again.** This is the failure ADR-0006 exists to describe, and it is being re-entered deliberately with eyes open: logind does not fall back, so `suspend-then-hibernate` on a machine that cannot hibernate leaves a laptop awake in a bag. `cat /sys/power/disk` is the whole check — `[disabled]` means this decision failed and ADR-0006 was right. The change is committed but not deployed anywhere until that has been read on the machine.

**A hibernation image is RAM in the clear on an unencrypted root.** ADR-0006 raises this as the reason the kernel's refusal is *correct*, and nothing about it has changed: `/swapfile` sits on an unencrypted ext4 root, so everything in memory at hibernate time — keys, unlocked vault contents, whatever a browser was holding — is readable by anyone with the disk. Accepted here as the price of the feature. Encrypting the root filesystem is the fix, and it is a separate piece of work.

**`nix flake check` still says nothing about any of this.** The check proves these options evaluate. It proved the ADR-0006 configuration evaluated too, and that one was green while being both refused by the kernel and unable to resume. ADR-0001's point, for the third time.
