{ self, ... }:
{
  # Noctalia's authored TOML, checked by noctalia itself.
  #
  # Noctalia ignores settings it does not recognise, so a renamed key is
  # invisible: the shell starts, the flake check passes, and the setting simply
  # stops doing anything. That is not hypothetical — `autoStartAuth` and
  # `allowPasswordWithFprintd` became `lockscreen.fingerprint` between noctalia
  # 4 and 5, and nothing anywhere would have reported it. The package is
  # unpinned and currently a 5.0.0 beta, so this is the live risk on every
  # nixpkgs bump.
  #
  # `validate` exits 0 on an unknown setting and only warns, so the exit code
  # alone is not enough — a warning has to be turned into a failure here, or
  # the check would go green on exactly the typo it exists to catch.
  perSystem =
    { pkgs, ... }:
    {
      checks.noctalia-config = pkgs.runCommand "noctalia-config-valid" { } ''
        # `validate` writes into the config and state dirs it resolves; point
        # them somewhere writable so the sandbox does not fail on $HOME.
        export HOME="$PWD"

        # Each file is validated on its own rather than by passing the
        # directory: `hosts/` and `shared/` are separate directories, and only
        # a per-file run resolves `[include]` relative to the file that wrote
        # it.
        for f in ${self}/.dotfiles/.config/noctalia/hosts/*.toml \
                 ${self}/.dotfiles/.config/noctalia/shared/*.toml; do
          echo "validating ''${f#${self}/}"
          ${pkgs.noctalia}/bin/noctalia config validate "$f" 2>&1 | tee out.txt
          if grep -q "WARN" out.txt; then
            echo "error: noctalia reported a warning above; an unknown setting is a typo or a renamed key" >&2
            exit 1
          fi
        done

        touch $out
      '';
    };
}
