# Noctalia replaces DankMaterialShell outright

The desktop shell — bar, launcher, lock screen, greeter and theming — is now noctalia. DankMaterialShell (DMS) is deleted rather than kept as a module we could switch back to, and the `quickshell` flake input goes with it, since nothing else referenced it.

Both shells are in nixpkgs, so this cost no new input on the shell side. The greeter did: nixpkgs packages `noctalia-greeter` but its NixOS module lives only in the upstream flake, so the flake is the input and package and module stay on one version. Taking the module from upstream and the package from nixpkgs would have paired a v1.2.1 module with a v1.0.0 package.

## Considered Options

**Rejected: keep DMS as an unimported fallback module.** An unimported module is never evaluated, so `nix flake check` cannot catch it rotting against nixpkgs churn. A fallback that has not been built in six months is not a fallback — and it compounds with noctalia being a beta: if the fallback is ever needed, it may itself need fixing first. `git revert` is the fallback, and it is one that was known to build at the commit it points at.

**Rejected: a second `nixosConfigurations.tower-dms` to keep the fallback verified.** This is the only way an unimported module stays honest, and it doubles the cold-build time of the verification surface for a configuration nobody runs.

**Rejected: `programs.noctalia.recommendedServices`.** It sets NetworkManager, bluetooth, UPower and a power-profile daemon. Three of those are already owned — NetworkManager by `base`, bluetooth and power profiles by `desktop`. A shell module should not be what turns the radio on. UPower is enabled explicitly instead, since noctalia's battery and power widgets are the only reason this fleet needs it.

**Rejected: declaring the greeter's `appearance`.** The greeter's declarative keys take precedence over the ones Sync Now writes, so declaring a palette would leave Settings → Security → Noctalia Greeter → Sync Now silently doing nothing. Only settings no machine can differ on are declared: the session, and the cursor the greeter cannot otherwise see because it runs as its own user.

**Rejected: a fixed starship palette.** Dropping matugen removes what themed the prompt. Putting format and palette in `programs.starship.settings` would be fully declarative, but noctalia's starship template is the direct replacement and a prompt that follows the wallpaper is worth the cost recorded below. Note that `programs.starship` only exports `STARSHIP_CONFIG` when `~/.config/starship.toml` does not exist, and this arrangement makes it exist — so the format must live in that file, not in `settings`.

## Consequences

**Settings tweaked in the UI no longer reach this repo.** This is the sharpest behavioral change and it is the opposite of what DMS did. Noctalia v5 splits its config: it reads `~/.config/noctalia/*.toml`, which is authored and linked out of the store, and writes `~/.local/state/noctalia/settings.toml`, which is runtime state and is not linked at all. A change in the settings panel therefore survives a rebuild but not a reinstall, and keeping one means copying it across with `noctalia config export merged`. In exchange, adjusting the shell no longer shows up as a dirty working tree.

**`.dotfiles/.config/starship.toml` is the one file that still churns.** It is tracked, because it carries the prompt format that matugen's template used to. Noctalia's starship template splices a palette block into it at runtime, writing through the symlink. `.gitignore` cannot help — the file is tracked by design — so expect it to appear modified after a theme change.

**Two shell-specific lines sit in files the session owns.** `include "noctalia.kdl"` in `niri/config.kdl` and `include themes/noctalia.conf` in `kitty/kitty.conf`. Both tools match on the literal line and append it if absent, writing through the symlink into a tracked file; niri's `apply.sh` greps `config.kdl` only and does not follow includes, so the line cannot be moved somewhere less conspicuous. Authored in place, both writes become no-ops.

**`~/.config/gtk-3.0/gtk.css` and `gtk-4.0/gtk.css` must never be managed by home-manager.** Noctalia's GTK template `rm`s a read-only symlink it finds at either path and writes a regular file in its place, with the comment `# Read-only symlink (e.g. NixOS): convert to a local file`. Today `home.pointerCursor` manages `settings.ini` and misses them; anything that puts `gtk.css` under home-manager would produce a fight with no winner. `adw-gtk3` is installed because the template sets the GTK theme only `if theme_exists`, and without it the colors apply while the surrounding widgets stay default Adwaita.

**`programs.dsearch` is gone with no replacement.** It backed DMS's spotlight file search. Noctalia's launcher has its own providers.

**The shell is a beta.** `pkgs.noctalia` is 5.0.0-beta.7, chosen over `pkgs.noctalia-shell` (4.x) because v5 is where the compositor integration and the config split live, and binding keys against v4 syntax would mean redoing them.
