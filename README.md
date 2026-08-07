## NixOS Configuration

A single Nix flake that builds and verifies every host in this repo, together with
its dotfiles. See `CONTEXT.md` for the vocabulary and `docs/adr/` for the
decisions behind it.

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
gets installed — this flake tracks `nixos-unstable` regardless.

If you need wifi in the installer:

```bash
sudo systemctl start wpa_supplicant
wpa_cli
# > add_network / set_network 0 ssid "..." / set_network 0 psk "..." / enable_network 0
```

### 2. Partition and format

Identify the disk:

```bash
lsblk
```

Everything below assumes `/dev/nvme0n1`. **This erases the disk.**

```bash
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
sudo parted /dev/nvme0n1 -- set 1 esp on
sudo parted /dev/nvme0n1 -- mkpart root ext4 1GiB 100%
```

The 1 GiB ESP is deliberate: the bootloader is Limine keeping 5 generations, on
`linuxPackages_latest`, so kernels and initrds add up.

```bash
sudo mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2
```

Mount them the way `hardware.nix` declares them — `/` ext4, `/boot` vfat, no
swap:

```bash
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount -o umask=077 /dev/disk/by-label/BOOT /mnt/boot
```

### 3. Clone the repo to its expected path

```bash
sudo mkdir -p /mnt/home/ansgar
sudo nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#git -c \
  git clone https://github.com/endxrpxl/nixos-config /mnt/home/ansgar/nixos-config
cd /mnt/home/ansgar/nixos-config
```

### 4. Read the real hardware values

```bash
sudo nix --extra-experimental-features 'nix-command flakes' \
  run .#regen-hardware -- --root /mnt laptop
```

This runs `nixos-generate-config` against the filesystems mounted under `/mnt`
and overwrites `modules/hosts/laptop/_hardware-generated.nix` with the result —
UUIDs, kernel modules and all. It prints the diff; read it before moving on.

Nothing else in the repo is touched. The decisions that sit beside the scan —
the `nixos-hardware` modules, the placeholder warning — live in
`modules/hosts/laptop/hardware.nix` and survive the refresh.

### 5. Clear the placeholder

Edit `modules/hosts/laptop/hardware.nix`:

- Delete the `warnings = [ ... ];` block and the comment above it. The values it
  warned about were replaced by the scan in the previous step.

Edit `modules/hosts/laptop/configuration.nix`:

- Set `console.keyMap` to the real layout and delete its `PLACEHOLDER` comment.
- Set `programs.noctalia-greeter.settings.keyboard.layout` to the same layout,
  and keep `.dotfiles/.config/niri/hosts/laptop.kdl` in step with it.
- Set `system.stateVersion` to the release actually being installed
  (`nixos-version` inside the installer), then never change it.

Then stage everything — the flake source is the git index, and an untracked
file is invisible to evaluation:

```bash
git add -A
```

### 6. Install

```bash
sudo nixos-install --root /mnt --flake /mnt/home/ansgar/nixos-config#laptop
```

The build pulls a full desktop closure and takes a while. `nixos-install`
prompts for the root password at the end.

### 7. First boot

```bash
sudo umount -R /mnt
sudo reboot
```

Remove the USB stick. Once booted, log in as root on a TTY and set up the user
account — no password is declared in the configuration:

```bash
passwd ansgar
chown -R ansgar:users /home/ansgar/nixos-config
```

Log in as `ansgar` and verify:

```bash
cd ~/nixos-config
nix flake check
```

### 8. Publish the cleared placeholder

```bash
cd ~/nixos-config
git config user.email <mail>
git commit -am "Replace laptop placeholder with real hardware values"
git push
```

Also update the host table at the top of this file, and note in
`docs/adr/0003-placeholder-host-in-the-verification-surface.md` that the
placeholder is cleared.

---

## Applying this config to an existing NixOS install

For a machine already running NixOS, where only the configuration changes.

### 1. Clone the repository

```bash
git clone https://github.com/endxrpxl/nixos-config.git ~/nixos-config
cd ~/nixos-config
```

The path matters — see the note under *Before you start*.

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

`nix flake check` is the success criterion — it builds every host's whole
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
