# Installation

Two paths: a fresh install onto a machine with no NixOS on it, and applying
this config to a machine that already runs NixOS.

## Installing onto a new machine

These steps install the `laptop` host. For another host, substitute its name
throughout.

### Before you start

- **Confirm the machine matches the host.** `laptopHardware` imports
  `lenovo-thinkpad-t14` and `common-cpu-intel`. A different machine needs a new
  host module.
- **Clone to the expected path.** `self.lib.repoDir` is
  `/home/ansgar/nixos-config`.

### 1. Boot the official minimal ISO

Download the NixOS minimal ISO from https://nixos.org/download and write it to a
USB stick:

```bash
sudo dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Boot it on the new machine. The installer's version does not matter, because
this flake tracks `nixos-unstable`.

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

The commands from here through the install run as root. `sudo -i` opens a root
shell, so the commands below have no `sudo` prefix. Type `exit` when the install
is done.

```bash
sudo -i
parted /dev/nvme0n1
# (parted) mklabel gpt
# (parted) mkpart ESP fat32 1MiB 1GiB
# (parted) set 1 esp on
# (parted) mkpart root ext4 1GiB 100%
# (parted) quit
```

The ESP is 1 GiB because Limine keeps 5 generations of `linuxPackages_latest`
kernels and initrds on it. The ESP stays unencrypted. Limine cannot decrypt, and
UEFI firmware loads `BOOTX64.EFI` from a FAT volume, so the ESP must be vfat.
Only the root partition is encrypted.

```bash
mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1
```

Format the root partition with LUKS, unlock it as `cryptroot`, then create the
filesystem inside the mapper device:

```bash
cryptsetup luksFormat /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 cryptroot
mkfs.ext4 -L nixos /dev/mapper/cryptroot
```

Add a recovery key in a second keyslot and store it in the Bitwarden vault. You
can reach the vault from the tower or a phone, and a thief cannot reach it from
the powered-off laptop, because the laptop's copy sits on the encrypted disk.

```bash
systemd-cryptenroll --recovery-key /dev/nvme0n1p2
```

Mount `/` from the LUKS mapper and `/boot` from the ESP. There is no swap
partition. `hardware.nix` declares a swapfile, and `mkswap-swapfile.service`
creates it on first boot.

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
and overwrites `modules/hosts/laptop/_hardware-generated.nix` with the result,
including UUIDs and kernel modules. It prints the diff. Read it before moving
on.

Because the root is on LUKS, the generated file declares
`boot.initrd.luks.devices."cryptroot"` and points `/` at
`/dev/mapper/cryptroot`. You don't need to write any of that by hand.

The script touches no other file. The `nixos-hardware` imports and the swapfile
live in `modules/hosts/laptop/hardware.nix`, which a rescan leaves alone.

### 5. Set what the scan cannot know

Edit `modules/hosts/laptop/configuration.nix`:

- Set `console.keyMap` to the machine's keyboard layout.
- Set `services.displayManager.noctalia-greeter.settings.keyboard.layout` to the
  XKB name of the same layout, and set the same layout in `.dotfiles/.config/niri/hosts/laptop.kdl`.
- Set `system.stateVersion` to the release you are installing
  (`nixos-version` inside the installer), then never change it. Set
  `home.stateVersion` in `modules/hosts/laptop/home.nix` to the same value.

Then stage everything. The flake only sees files in the git index, so an
untracked file does not exist for evaluation:

```bash
git add -A
```

### 6. Install

```bash
nixos-install --root /mnt --flake /mnt/home/ansgar/nixos-config#laptop
```

The build downloads a full desktop closure and takes a while. `nixos-install`
asks for the root password at the end.

### 7. First boot

```bash
umount -R /mnt
reboot
```

Remove the USB stick. The configuration declares no user password, so log in as
root on a TTY and set one:

```bash
passwd ansgar
chown -R ansgar:users /home/ansgar/nixos-config
```

Log in as `ansgar` and verify:

```bash
cd ~/nixos-config
nix flake check
```

On `laptop`, enroll the TPM so the disk unlocks without a passphrase. The sealed
key lives in the TPM and in a keyslot in the LUKS header, so the configuration
cannot do this. Until you run it, every boot asks for the passphrase:

```bash
sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto \
  --tpm2-pcrs=4+9+12 /dev/disk/by-uuid/<luks-partition-uuid>
```

The UUID is the one `regen-hardware` wrote into
`boot.initrd.luks.devices."cryptroot".device` in
`modules/hosts/laptop/_hardware-generated.nix`. The command asks for the
existing passphrase, wipes any previous TPM enrollment and seals a fresh key
against PCRs 4, 9 and 12. Re-running it is safe. Run it again when the TPM stops
unsealing, which shows up as an unexpected passphrase prompt at boot. A Limine
package update changes PCR 4 and causes this. The passphrase and recovery
keyslots stay enrolled as the fallback.

On `laptop`, enroll a fingerprint. The templates live on the sensor, so the
configuration cannot do this. Until you run it, `nix flake check` passes but the
lock screen and polkit prompts ignore your finger:

```bash
fprintd-enroll          # repeat with -f for further fingers
fprintd-verify          # confirm the reader matches what was enrolled
```

If `fprintd-enroll` reports no device, the reader may still hold enrollments
from a previous Windows install, or need newer firmware
(`fwupdmgr get-updates`).

### 8. Publish the result

```bash
cd ~/nixos-config
git config user.email <mail>
git commit -am "Add real hardware values for laptop"
git push
```

If the machine is a new host, add it to the host table in the README.

---

## Applying this config to an existing NixOS install

For a machine that already runs NixOS, where only the configuration changes.

### 1. Clone the repository

```bash
git clone https://github.com/endxrpxl/nixos-config.git ~/nixos-config
cd ~/nixos-config
```

The path matters. See _Clone to the expected path_ above.

### 2. Record the machine's hardware

```bash
sudo nix run .#regen-hardware -- <host>
```

This writes `modules/hosts/<host>/_hardware-generated.nix` from a fresh
`nixos-generate-config` scan, formats it, stages it, and prints the diff. The
host defaults to the running machine's hostname, so you only need the argument
when the two differ.

Run it under `sudo`. An unprivileged scan misses devices only root can see, and
nothing checks the resulting hardware file for that.

### 3. (Optional) Change the username

The username is a global constant in `modules/lib/lib.nix`, not a host setting.
Change `username` there to your login name.

`.dotfiles/.config/noctalia/shared/base.toml` also hardcodes
`/home/ansgar/...` in `wallpaper.default.path`. Update it too.

### 4. Build and switch

`nh` is not installed yet, so the first build uses `nixos-rebuild`:

```bash
sudo nixos-rebuild boot --flake .#<host>
systemctl reboot
```
