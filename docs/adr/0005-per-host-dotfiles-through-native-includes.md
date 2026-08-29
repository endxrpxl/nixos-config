# Per-host dotfiles through each format's own include mechanism

A dotfile splits into a shared half and a per-host half using whatever include mechanism its own format already has. The per-host half is a file under `hosts/` in the repo, linked to a fixed name the shared half includes: `niri/hosts/<host>.kdl` becomes `~/.config/niri/host.kdl`, and `noctalia/hosts/<host>.toml` becomes `~/.config/noctalia/config.toml`. The hostname selects it, read from `osConfig.networking.hostName`.

Before this, `.dotfiles/.config` was one tree linked wholesale, so a second host could only ever be wrong: `niri/config.kdl` hardcoded `layout "gb,gb"` while the laptop declares a German keymap, and the monitor layout named connectors only the tower has.

Every file stays an out-of-store symlink, which is the property the arrangement exists to preserve. An edit takes effect without a rebuild, and files can be edited in place by whatever writes them.

## Considered Options

**Rejected: overlay directories.** A `common/` tree plus a `hosts/<host>/` tree, merged in home-manager with the host winning. It works for any format, including ones with no include mechanism. It also breaks the out-of-store property for exactly the files that matter: once two trees can both supply `niri/config.kdl`, home-manager has to merge them into a store path, and the merged result is no longer a file you can edit. Reintroducing per-host config by giving up in-place editing would have traded away the reason for the split.

**Rejected: naming the per-host file in the include line.** `include "hosts/tower.kdl"` reads more plainly than `include "host.kdl"`, but it makes `config.kdl` itself per-host, which is the thing being avoided. Keeping the indirection in the symlink means every host reads a byte-identical shared file.

**Rejected: naming the host in each host's home module.** `homeModules.tower` could pass `"tower"` explicitly. ADR-0002 already makes the hostname the host's identity, so restating it in the home module is a second place to get it wrong.

**Rejected: relying on noctalia's alphabetical autoload.** Noctalia loads every `*.toml` in the root of its config directory in alphabetical order, so `config.toml` and `shared.toml` sitting side by side would load in that order and the shared file would override the host's values. That is backwards, and invisible unless you know the rule. The shared half therefore lives in a subdirectory, which is not autoloaded, and comes in through an explicit `[include]`. Included files load first and the including file overrides them, which is the wanted precedence and is written down rather than inferred.

The documented `autoload = false` key, which would have allowed a flat layout, is rejected by 5.0.0-beta.7 as an unknown section. The subdirectory arrangement does not depend on it.

## Consequences

**A missing per-host file fails `nix flake check` rather than producing a dangling symlink.** The path is built from the hostname and so never appears literally at the call site, which is exactly the case a typo survives. `self.lib.authoredDotfile` asserts the path exists in the flake source at eval time. A consequence worth knowing: an untracked file does not exist as far as the flake source is concerned, so a new per-host file must be `git add`ed before it will evaluate.

**Both sides are real, and the check still cannot tell.** `tower` and `laptop` now each carry values read off the machine. That is a fact about the machines, not something `nix flake check` established: a connector name invented today would evaluate exactly as green as `eDP-1` does. The check proves the split evaluates for both hosts, never that either half is right. The `laptop` files were deliberately near-empty until the hardware arrived for that reason. See ADR-0003.

**A host's keyboard layout is now stated in three places:** `console.keyMap`, the greeter's `keyboard.layout`, and the niri per-host file. They are three different naming schemes for it. `console.keyMap = "uk"` is a kbd keymap name and is not a valid XKB layout, where the same layout is `gb`, so no one of them can be derived from another.

**Only files that are linked remain in `.dotfiles`.** Runtime output, the snippets noctalia regenerates and the settings the UI writes, is no longer linked anywhere, so the tree is now readable as "these are the files a human writes", with `starship.toml` the single documented exception.
