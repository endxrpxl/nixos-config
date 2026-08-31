## NixOS Configuration

A single Nix flake that builds and verifies every host in this repo, together with
its dotfiles. See `CONTEXT.md` for the vocabulary.

Hosts:

| Host | Machine |
| --- | --- |
| `tower` | Desktop |
| `laptop` | ThinkPad T14 Gen 3 (Intel) |

---

## Installing onto a new machine

This is the full path for a machine that has no NixOS on it yet. It assumes
you are installing the `laptop` host; substitute the host name throughout if
not.

### Before you start

- **Confirm the machine matches the host.** `laptopHardware` imports
  `lenovo-thinkpad-t14` and `common-cpu-intel`. A different machine needs a new
  host module, not a rename.
- **Decide which branch to install from.** The steps below clone the default
  branch.
- **The clone path is not free.** `self.lib.repoDir` is `/home/ansgar/nixos-config`
  and authored dotfiles are symlinked out of `$repoDir/.dotfiles` on disk. Clone
  anywhere else and every dotfile symlink dangles with `nix flake check` still
  green. See the comment at `modules/lib/lib.nix:33`.

### 1. Boot the official minimal ISO

Download the NixOS minimal ISO from https://nixos.org/download and write it to a
USB stick:

```bash
sudo dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Boot it on the new machine. The installer's own version does not affect what
gets installed. This flake tracks `nixos-unstable` regardless.

If you need wifi in the installer:

```bash
sudo systemctl start wpa_supplicant
wpa_cli
# > add_network / set_network 0 ssid "..." / set_network 0 psk "..." / enable_network 0
```

### 2. Partition, format and encrypt

Identify the disk:

```bash
lsblk
```

Everything below assumes `/dev/nvme0n1`. **This erases the disk.**

The commands from here through the install run as root: `sudo -i` opens an
interactive root shell (`#` prompt) so every command below drops its `sudo`
prefix. Type `exit` when the install session is done.

```bash
sudo -i
parted /dev/nvme0n1
# (parted) mklabel gpt
# (parted) mkpart ESP fat32 1MiB 1GiB
# (parted) set 1 esp on
# (parted) mkpart root ext4 1GiB 100%
# (parted) quit
```

The 1 GiB ESP is deliberate: the bootloader is Limine keeping 5 generations, on
`linuxPackages_latest`, so kernels and initrds add up. The ESP stays plaintext —
Limine cannot decrypt, and UEFI firmware loads `BOOTX64.EFI` from a FAT volume,
so the ESP must be vfat. The root partition is what gets encrypted.

```bash
mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1
```

The root partition is LUKS-encrypted. Format it, unlock it as `cryptroot`, then
put the filesystem *inside* the mapper device:

```bash
cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot
mkfs.ext4 -L nixos /dev/mapper/cryptroot
```

Add a recovery key in a second keyslot and store it in the Bitwarden vault —
reachable from the tower, the phone, or any device, and unreachable from a
stolen, powered-off laptop (the vault is on the protected disk):

```bash
systemd-cryptenroll --recovery-key /dev/nvme0n1p2
```

Mount them the way `hardware.nix` declares them — `/` ext4 behind LUKS, `/boot`
vfat, no swap:

```bash
mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/BOOT /mnt/boot
```

### 3. Clone the repo to its expected path

```bash
mkdir -p /mnt/home/ansgar
nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#git -c \
  git clone https://github.com/endxrpxl/nixos-config /mnt/home/ansgar/nixos-config
cd /mnt/home/ansgar/nixos-config
```

### 4. Read the real hardware values

```bash
nix --extra-experimental-features 'nix-command flakes' \
  run .#regen-hardware -- --root /mnt laptop
```

This runs `nixos-generate-config` against the filesystems mounted under `/mnt`
and overwrites `modules/hosts/laptop/_hardware-generated.nix` with the result:
UUIDs, kernel modules and all. It prints the diff; read it before moving on.

Because the root is LUKS, the generated file will now declare
`boot.initrd.luks.devices."cryptroot"` and point `/` at `/dev/mapper/cryptroot`.
That is what the `luksExpected` assertion in `hardware.nix` checks once the flag
is flipped, so nothing needs writing by hand.

Nothing else in the repo is touched. The decisions that sit beside the scan,
the `nixos-hardware` modules, live in `modules/hosts/laptop/hardware.nix` and
survive the refresh.

### 5. Set what the scan cannot know

Edit `modules/hosts/laptop/configuration.nix`:

- Set `console.keyMap` to the machine's real layout.
- Set `programs.noctalia-greeter.settings.keyboard.layout` to the same layout,
  and keep `.dotfiles/.config/niri/hosts/laptop.kdl` and
  `.dotfiles/.config/umbriel/hosts/laptop.toml` in step with it.
- Set `system.stateVersion` to the release actually being installed
  (`nixos-version` inside the installer), then never change it.

Then stage everything. The flake source is the git index, and an untracked
file is invisible to evaluation:

```bash
git add -A
```

### 6. Install

```bash
nixos-install --root /mnt --flake /mnt/home/ansgar/nixos-config#laptop
```

The build pulls a full desktop closure and takes a while. `nixos-install`
prompts for the root password at the end.

### 7. First boot

```bash
umount -R /mnt
reboot
```

Remove the USB stick. Once booted, log in as root on a TTY and set up the user
account. No password is declared in the configuration:

```bash
passwd ansgar
chown -R ansgar:users /home/ansgar/nixos-config
```

Log in as `ansgar` and verify:

```bash
cd ~/nixos-config
nix flake check
```

The root filesystem is now encrypted, but the assertion in `hardware.nix` is
still gated off — `luksExpected = false`. Once the install is confirmed and
the machine boots with LUKS, flip the flag to `true` in
`modules/hosts/laptop/hardware.nix` — the human half of hardware, where this
decision belongs:

```nix
luksExpected = true;
```

Then rebuild and re-check. Once the flag is on, `nix flake check` fails if the
root ever stops being a LUKS mapper device — wipe back to plaintext and re-run
`regen-hardware` and the build catches it.

On `laptop`, enroll the TPM so the disk unlocks without a passphrase. The
sealed key lives in the TPM plus a keyslot in the LUKS header, so nothing
declarative can do this — a fresh install prompts for the passphrase at every
boot until this is run:

```bash
sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto \
  --tpm2-pcrs=4+9+12 /dev/disk/by-uuid/<luks-partition-uuid>
```

The UUID is the one `regen-hardware` wrote into
`boot.initrd.luks.devices."cryptroot".device` in
`modules/hosts/laptop/_hardware-generated.nix`. The command asks for the
existing passphrase, wipes any previous TPM enrollment and seals a fresh key
against PCRs 4+9+12, so re-running it is always safe — and it is the fix when
the TPM stops unsealing (a Limine package update moves PCR 4), which shows up
as an unexpected passphrase prompt at boot. The passphrase and recovery
keyslots stay enrolled as the fallback for exactly that case.

On `laptop`, enroll a fingerprint. Nothing declarative can do this — the
templates live on the sensor, so a fresh install has a green `nix flake check`
and a lock screen that ignores your finger until this is run:

```bash
fprintd-enroll          # repeat with -f for further fingers
fprintd-verify          # confirm the reader matches what was enrolled
```

If `fprintd-enroll` reports no device, the reader may still be holding
enrollments from a previous Windows install, or want newer firmware
(`fwupdmgr get-updates`). Nothing downstream works until this command does.

### 8. Publish the result

```bash
cd ~/nixos-config
git config user.email <mail>
git commit -am "Add real hardware values for laptop"
git push
```

Also update the host table at the top of this file if the machine is new.

---

## Applying this config to an existing NixOS install

For a machine already running NixOS, where only the configuration changes.

### 1. Clone the repository

```bash
git clone https://github.com/endxrpxl/nixos-config.git ~/nixos-config
cd ~/nixos-config
```

The path matters. See the note under *Before you start*.

### 2. Record the machine's hardware

```bash
sudo nix run .#regen-hardware -- <host>
```

Writes `modules/hosts/<host>/_hardware-generated.nix` from a fresh
`nixos-generate-config` scan, formats it, stages it, and prints the diff. The
host defaults to the running machine's hostname, so the argument is only needed
when they differ.

Run it under `sudo`: an unprivileged scan silently misses devices only root can
see, and the result is a hardware file that is wrong in ways nothing checks.

### 3. (Optional) Configure your identity

The system user is a global constant, not a host setting.

- **File:** `modules/lib/lib.nix`
- **Action:** change `username` to your login name.

### 4. Build and switch

```bash
sudo nixos-rebuild boot --flake .#tower
systemctl reboot
```

---

## Day to day

`nix flake check` is the success criterion. It builds every host's whole
closure, so a cold run is slow by design. `nix fmt` fixes a formatting failure.

```bash
nix flake check          # verify
nix fmt                  # format
sudo nixos-rebuild switch --flake .#tower
nix flake update         # bump inputs, then re-check
sudo nix run .#regen-hardware   # re-scan this machine's hardware
```

Hardware is the one thing this repo cannot decide for itself. Each host's
`_hardware-generated.nix` is the scan, refreshed by the command above and never
edited by hand; its `hardware.nix` is the human half. The scan is committed
rather than read live from `/etc/nixos`, so every host stays inside `nix flake
check` and stays buildable from any machine.
