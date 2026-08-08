# At-rest protection with a LUKS passphrase

Both hosts encrypt their root filesystem with LUKS and unlock it at boot by typing a passphrase. The adversary this defends against is powered-off possession of the machine — a thief who holds the disk and the machine together — and the design is deliberately the smallest thing that covers that adversary: no TPM, no encrypted `/boot`, no biometric at the decryption gate. The vocabulary lives in `CONTEXT.md` as *at-rest protection* and *decryption gate*.

The passphrase is typed at every boot on both hosts. A printed recovery key in a second keyslot is stored in the Bitwarden vault, reachable off the protected machine — not on it, because the vault sits *on* the disk the key exists to recover.

## Considered Options

**Rejected: TPM2 auto-unlock.** A TPM-only keyslot hands the disk to whoever holds the machine: the attacker presses power and the TPM unseals the key into their hands. That is worse than plaintext, because it preserves the ritual of unlocking while guarding nothing. A TPM2+PIN slot does defend — the PIN is a secret the thief lacks — but it is the passphrase with extra steps and a shorter, weaker secret.

**Rejected: a FIDO2 security key.** A second keyslot on a hardware token survives a forgotten passphrase. It also costs hardware to buy, a thing to carry, and a failure mode — the token dies and the machine is a paperweight until the recovery key is found. The recovery key already covers the forgotten-passphrase case with nothing to carry.

**Rejected: the fingerprint sensor at the decryption gate.** A fingerprint match is a boolean from the sensor, not key material; there is nothing to enroll into a LUKS keyslot. And even if the sensor could export bytes, fingerprints are not secrets — the thief has the machine, and the machine has your prints on it. The sensor stays where it belongs, on the authentication side of the line ADR-0008 draws: the lock screen, *after* the disk is open.

**Rejected: encrypted `/boot` plus Secure Boot.** The ESP holds no private data — kernels and initrds are free to give away — so leaving it plaintext costs nothing against the reading adversary. Encrypting it would defend against evil-maid tampering, which is a hardware-forensics bar this project set out of scope. The change is a small plaintext ESP holding only the bootloader, kernels inside LUKS, and a Secure Boot signing chain that breaks on every hardware change.

**Rejected: systemd-initrd, for now.** The TPM and `HibernateLocation` tooling that justifies `boot.initrd.systemd.enable = true` is unused here — no TPM, no hibernation — and the classic stage-1 handles a LUKS root out of the box, so this is the smaller diff. The rejection has a shelf life: upstream has deprecated scripted initrd and schedules its removal in 26.11, at which point systemd-initrd becomes mandatory and the migration happens whether or not the TPM features are wanted.

## Consequences

**This removes the premise behind ADR-0006 and ADR-0008.** ADR-0006 argued the kernel was right to refuse hibernation because a hibernation image on an unencrypted root would be RAM in the clear. The root is now encrypted, so that specific objection dies — but the kernel gate does not ask whether the disk is encrypted, so no-hibernation stands. ADR-0008 justified the fingerprint's "convenience, not security" label with "the root filesystem is unencrypted, so anyone holding the machine reads it from a USB stick regardless". That sentence dies; the conclusion survives on a corrected premise — a fingerprint still cannot unlock at-rest protection.

**The swapfile becomes encrypted for free.** The laptop's 20 GiB swapfile lives inside the root filesystem, so it sits inside the LUKS container. Paging no longer writes plaintext to disk. Nothing needed declaring for this; it is a consequence of where the swapfile already was.

**Migration is a wipe-and-reinstall, one host at a time.** There is no in-place conversion from plaintext ext4 to LUKS on this layout; the README's install procedure is the migration path, and each host is reinstalled and then re-scanned with `regen-hardware`. The `_hardware-generated.nix` for a LUKS root then carries the `cryptroot` mapper as `/`, which is exactly what the module's assertion checks. On the tower this means the agreed wipe also takes its Windows dual-boot: the README procedure erases the disk, and the tower's `boot.loader.limine.extraEntries` and `hardwareClockInLocalTime` describe a machine that will no longer exist — a consequence of the migration, not a separate decision here.

**A host opts in with `security.atRestProtection.enable`, and the check enforces it.** Both hosts import the `disk-encryption` module, but the flag stays off until a machine has actually been reinstalled with LUKS. Flipping it is the last step of migration. Once on, the module asserts the root filesystem is a LUKS mapper device, so wiping back to plaintext and re-running `regen-hardware` fails `nix flake check` — a machine-truth property the verification surface can actually hold, unlike the kernel gates of ADR-0006.

**The recovery key lives in Bitwarden, not on the machine.** The vault is cloud-synced, so the key is reachable from the tower, the phone, or any device once the laptop is gone — and it is unreachable from a stolen, powered-off laptop, because the vault is *on* the encrypted disk. The circularity is broken by having the vault on other machines too.
