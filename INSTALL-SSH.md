# Installing over SSH

This is the fresh install from [INSTALL.md](INSTALL.md), driven from a second
machine. The new machine boots the installer and starts SSH. You do the rest in
a terminal on the tower, where you can paste each block below instead of typing
it into the installer console.

[INSTALL.md](INSTALL.md) explains why each step exists. This guide only lists
the commands. Read the full guide once before your first install.

## 1. On the new machine

Boot the NixOS minimal ISO (see step 1 of [INSTALL.md](INSTALL.md)) and connect
it to the network. Ethernet works without setup. Then set a password for the
`nixos` user, which turns on SSH logins, and read the machine's IP address:

```bash
passwd
ip -br a
```

You don't need the new machine's keyboard after this point until the first boot.

## 2. Connect from the tower

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null nixos@<ip>
```

The installer creates fresh host keys on every boot. The two `-o` options stop
SSH from recording them in `~/.ssh/known_hosts` and from refusing the next
installer with a changed-key warning.

Open a root shell and set the variables the later blocks use. Check the disk
name with `lsblk` first. **Everything on `$disk` is erased.**

```bash
sudo -i
lsblk
host=laptop
disk=/dev/nvme0n1
export NIX_CONFIG="experimental-features = nix-command flakes"
```

`NIX_CONFIG` turns on flakes for this shell, so the `nix` commands below don't
need `--extra-experimental-features`.

The partition names below (`${disk}p1`, `${disk}p2`) fit NVMe disks. For a SATA
disk such as `/dev/sda`, the partitions are `/dev/sda1` and `/dev/sda2`, so drop
the `p`.

## 3. Partition, format and mount

```bash
parted -s "$disk" -- mklabel gpt \
  mkpart ESP fat32 1MiB 1GiB set 1 esp on \
  mkpart root ext4 1GiB 100%
mkfs.fat -F 32 -n BOOT "${disk}p1"
cryptsetup luksFormat "${disk}p2"
cryptsetup open "${disk}p2" cryptroot
mkfs.ext4 -L nixos /dev/mapper/cryptroot
systemd-cryptenroll --recovery-key "${disk}p2"
```

`cryptsetup luksFormat` asks you to type `YES` and then the passphrase.
`systemd-cryptenroll` prints the recovery key. Copy it from the terminal into
Bitwarden.

```bash
mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/BOOT /mnt/boot
```

## 4. Clone and scan the hardware

```bash
mkdir -p /mnt/home/ansgar
nix shell nixpkgs#git -c git clone https://github.com/endxrpxl/nixos-config /mnt/home/ansgar/nixos-config
cd /mnt/home/ansgar/nixos-config
nix run .#regen-hardware -- --root /mnt "$host"
```

Read the diff that `regen-hardware` prints before going on.

## 5. Set the keyboard layout and state version

```bash
nixos-version
nano "modules/hosts/$host/configuration.nix"
```

Set `services.xserver.xkb.layout` and `system.stateVersion`. Use the release
that `nixos-version` printed for the state version. Then stage the changes,
because the flake ignores files outside the git index:

```bash
nix shell nixpkgs#git -c git add -A
```

## 6. Install and set the user password

```bash
nixos-install --root /mnt --flake "/mnt/home/ansgar/nixos-config#$host"
nixos-enter --root /mnt -c 'passwd ansgar && chown -R ansgar:users /home/ansgar/nixos-config'
umount -R /mnt
reboot
```

`nixos-install` asks for the root password at the end. `nixos-enter` runs
`passwd` inside the new system, so you can log in as `ansgar` on the first boot
and skip the root login on a TTY.

The SSH session ends at `reboot`. The installed system does not run an SSH
server, so the rest happens at the new machine.

## 7. First boot

Remove the USB stick and log in as `ansgar`. On `laptop`, enroll the TPM and a
fingerprint as described in step 7 of [INSTALL.md](INSTALL.md). Both need the
booted system and cannot run from the installer. Then commit and push the
hardware scan as in step 8.
