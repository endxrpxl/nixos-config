## NixOS Configuration

### Quick Start & Installation

#### 1. Clone the Repository
Clone this configuration into your home directory:
```bash
git clone https://github.com/endxrpxl/nixos-config.git ~/nixos-config
cd ~/nixos-config
```

#### 2. Configure Your Identity
Before building, you must update the global username to match your desired system user.

*   **File:** `modules/lib/lib.nix` (or your equivalent path)
*   **Action:** Change the `username` value to your preferred login name.

#### 3. Build and Switch
Apply the configuration to your system.

##### Desktop

```bash
sudo nixos-rebuild switch --flake .#desktop
```
