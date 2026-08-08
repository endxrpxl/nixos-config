{ self, inputs, ... }:
{
  # At-rest protection, asserted without a machine. The module's guarantee is
  # that an opted-in host's root filesystem is a LUKS mapper device, and this
  # check proves the assertion actually fires — and only when it should — by
  # evaluating the module against synthetic roots. The real hosts cannot prove
  # this from within the verification surface (ADR-0001's point: the check is
  # about the configuration, never the machine), but the assertion's own logic
  # is configuration, so it is testable here.
  perSystem =
    { pkgs, system, ... }:
    let
      # A minimal host for exercising the module: root filesystem set by hand,
      # nothing else. Forcing the toplevel derivation path evaluates the whole
      # configuration — including `config.assertions`, where the module throws —
      # without building anything, which is what lets `tryEval` report whether
      # the assertion fired.
      eval =
        root: enable:
        (inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.disk-encryption
            {
              security.atRestProtection.enable = enable;
              fileSystems."/" = {
                device = root;
                fsType = "ext4";
              };
              # A bootable system is required for the toplevel to evaluate at
              # all; the bootloader is incidental to what is under test.
              boot.loader.systemd-boot.enable = true;
              system.stateVersion = "26.05";
            }
          ];
        }).config.system.build.toplevel.drvPath;
      # A root must either evaluate (ok) or not (FAIL); which of the two is
      # correct depends on the case being tested.
      probe = root: enable: if (builtins.tryEval (eval root enable)).success then "ok" else "FAIL";
      # Invert the probe result when the correct outcome is "must not evaluate".
      mustFail = root: enable: if probe root enable == "FAIL" then "ok" else "FAIL";
    in
    {
      checks.disk-encryption-assertion =
        pkgs.runCommand "disk-encryption-assertion"
          {
            # A mapper root with at-rest protection enabled must evaluate.
            mapper = probe "/dev/mapper/cryptroot" true;
            # A plaintext root with at-rest protection enabled must not evaluate:
            # this is the regen-on-plaintext case the module exists to catch.
            plaintextEnabled = mustFail "/dev/disk/by-uuid/11111111-2222-3333-4444-555555555555" true;
            # A plaintext root with at-rest protection disabled must evaluate: the
            # gate is an opt-in, not a property of every host in the flake.
            plaintextDisabled = probe "/dev/disk/by-uuid/11111111-2222-3333-4444-555555555555" false;
          }
          ''
            set -eu
            [ "$mapper" = ok ] || { echo "error: mapper root with at-rest protection did not evaluate" >&2; exit 1; }
            [ "$plaintextEnabled" = ok ] || { echo "error: plaintext root with at-rest protection evaluated; the assertion did not fire" >&2; exit 1; }
            [ "$plaintextDisabled" = ok ] || { echo "error: plaintext root without at-rest protection did not evaluate; the gate fires when it should not" >&2; exit 1; }
            echo "at-rest protection assertion: mapper accepted, plaintext rejected, opt-in gating correct"
            touch $out
          '';
    };
}
