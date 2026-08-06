## NixOS Configuration

### Quick Start & Installation

#### 1. Clone the Repository
Clone this configuration into your home directory:
```bash
git clone https://github.com/endxrpxl/nixos-config.git ~/nixos-config
cd ~/nixos-config
```

#### 2. Update hardware.nix
Copy the contents of `/etc/nixos/hardware-configuration.nix` into `modules/hosts/<host>/hardware.nix`

#### (Optional) Configure Your Identity
Before building, you must update the global username to match your desired system user.

*   **File:** `modules/lib/lib.nix` (or your equivalent path)
*   **Action:** Change the `username` value to your preferred login name.

#### 3. Build and Switch
Apply the configuration to your system.

##### Tower-Host

```bash
sudo nixos-rebuild boot --flake .#tower
systemctl reboot
```

The flake also defines a `laptop` host. It is a placeholder until the machine
exists — its filesystem UUIDs and keymap are not real values, so it builds but
does not boot. See `docs/adr/0003-placeholder-host-in-the-verification-surface.md`.
