{ self, ... }:
{
  # Noctalia's authored TOML, checked by noctalia itself.
  #
  # Noctalia ignores settings it does not recognize, so a renamed key is
  # otherwise invisible: the shell starts, the flake check passes, and the
  # setting simply stops doing anything. The package is unpinned and currently
  # a 5.0.0 beta, so that is the live risk on every nixpkgs bump.
  perSystem =
    { pkgs, ... }:
    {
      checks.noctalia-config = pkgs.runCommand "noctalia-config-valid" { } ''
        # stdenv already sets `-eu -o pipefail`, which is what makes `validate`
        # exiting non-zero through the pipe below fail the build. Restated here
        # because this check reasons about exit codes, and inheriting that
        # silently is the kind of thing a stdenv change removes without notice.
        set -eu -o pipefail

        # An unmatched glob would otherwise be passed through literally, and
        # whether `validate` rejects a nonexistent path is not something to
        # depend on. The counter below turns a renamed or emptied directory
        # into a failure rather than a silent pass over zero files.
        shopt -s nullglob

        # `validate` writes into the config and state dirs it resolves; point
        # them somewhere writable so the sandbox does not fail on $HOME.
        export HOME="$PWD"

        checked=0

        # Each file is validated on its own rather than by passing the
        # directory: `hosts/` and `shared/` are separate directories, and only
        # a per-file run resolves `[include]` relative to the file that wrote
        # it.
        for f in ${self}/.dotfiles/.config/noctalia/hosts/*.toml \
                 ${self}/.dotfiles/.config/noctalia/shared/*.toml; do
          echo "validating ''${f#${self}/}"
          ${pkgs.noctalia}/bin/noctalia config validate "$f" 2>&1 | tee out.txt

          # A bad value or broken syntax exits non-zero and is already fatal
          # above. An *unknown* setting only warns and exits 0, which is
          # precisely the renamed-key case this check exists for, so the
          # warning has to be promoted to a failure by hand.
          if grep -qE "WARN|unknown setting" out.txt; then
            echo "error: noctalia reported a warning above; an unknown setting is a typo or a renamed key" >&2
            exit 1
          fi

          checked=$((checked + 1))
        done

        if [ "$checked" -eq 0 ]; then
          echo "error: no noctalia TOML matched; the authored dotfiles moved and this check stopped checking anything" >&2
          exit 1
        fi

        echo "validated $checked file(s)"
        touch $out
      '';
    };
}
