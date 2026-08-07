{ lib, ... }:
{
  # `nix run .#regen-hardware [--root DIR] [host]` — rescan the machine it runs
  # on and rewrite that host's `_hardware-generated.nix`. The host defaults to
  # the running machine's hostname.
  #
  # This is the pure half of "read the hardware the installer generated". The
  # scan happens when a human asks for it, on the machine being described, and
  # lands in git where the flake can see it; the alternative — importing
  # /etc/nixos/hardware-configuration.nix at eval time — needs `--impure`,
  # takes every host out of `nix flake check`, and makes a host buildable only
  # from itself.
  perSystem =
    { config, pkgs, ... }:
    let
      regen-hardware = pkgs.writeShellApplication {
        name = "regen-hardware";
        runtimeInputs = [
          pkgs.nixos-install-tools # nixos-generate-config
          pkgs.git
          config.treefmt.build.wrapper
        ];
        text = ''
          # `--root` is passed straight through to nixos-generate-config, for
          # the one case where the machine being described is not the machine
          # running the scan: an installer with the new system's filesystems
          # mounted under /mnt, which is where a first install happens.
          root_arg=()
          if [ "''${1-}" = "--root" ]; then
            root_arg=(--root "$2")
            shift 2
          fi

          host=''${1:-$(cat /proc/sys/kernel/hostname)}

          root=$(git rev-parse --show-toplevel)
          cd "$root"

          if [ ! -d "modules/hosts/$host" ]; then
            echo "regen-hardware: no host '$host' under modules/hosts" >&2
            exit 1
          fi

          if [ "$(id -u)" -ne 0 ]; then
            echo "regen-hardware: not running as root; the scan may miss" \
                 "devices only root can see" >&2
          fi

          target="modules/hosts/$host/_hardware-generated.nix"
          scratch=$(mktemp)
          trap 'rm -f "$scratch"' EXIT

          {
            echo "# GENERATED — do not edit. Written by \`nix run .#regen-hardware\`, which"
            echo "# reruns \`nixos-generate-config --show-hardware-config\` on the machine this"
            echo "# host describes. Hand-written hardware configuration belongs next door in"
            echo "# hardware.nix; anything added here is lost on the next refresh."
            # Drop the upstream header, which points at /etc/nixos and is wrong
            # here: keep from the module's argument line onward.
            nixos-generate-config --show-hardware-config "''${root_arg[@]}" \
              | sed -n '/^{/,$p'
          } > "$scratch"

          # A scan that produced no root filesystem is a failed scan, not a
          # machine without disks. Refuse to overwrite a good file with it.
          if ! grep -q 'fileSystems."/"' "$scratch"; then
            echo "regen-hardware: scan produced no root filesystem; $target left alone" >&2
            exit 1
          fi

          cp "$scratch" "$target"

          # The formatting check is part of `nix flake check`, so the generated
          # file has to satisfy it too.
          treefmt "$target" >/dev/null

          # A file the flake cannot see is a file that does not exist: an
          # untracked path is not part of the flake source, so a brand-new
          # host's hardware would fail to evaluate until it reached the index.
          git add --intent-to-add -- "$target"

          echo "regen-hardware: wrote $target"
          git --no-pager diff -- "$target"
        '';
      };
    in
    {
      apps.regen-hardware.program = lib.getExe regen-hardware;
    };
}
