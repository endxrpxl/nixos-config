{ lib, ... }:
{
  # At-rest protection: the property that a powered-off machine's storage
  # cannot be read without a decryption secret. The mechanism is LUKS on the
  # root filesystem; the boot-time act of proving the machine may decrypt is
  # the decryption gate, distinct from an authentication surface (which asks a
  # human to prove identity — see CONTEXT.md).
  #
  # The adversary this exists against is powered-off possession of the machine
  # — a thief with the disk and the machine together. It does nothing against a
  # running machine, an attacker with root, or a device left powered on. The
  # design is the smallest thing that covers that adversary — passphrase at
  # boot, plaintext ESP, classic stage-1 initrd, no TPM — and the full
  # reasoning, with the alternatives rejected, is in
  # docs/adr/0009-at-rest-protection-with-a-luks-passphrase.md.
  #
  # A host opts in with `security.atRestProtection.enable`. While the flag is
  # off the module is inert — the hosts in this flake are plaintext until they
  # are wiped and reinstalled per the README, and flipping the flag is the last
  # step of that migration, done on a machine whose root really is a mapper
  # device. The assertion below is that guarantee: an opted-in host whose root
  # is not a LUKS mapper device fails `nix flake check`, so wiping back to
  # plaintext and re-running `regen-hardware` stops the build.
  flake.nixosModules.disk-encryption =
    { config, lib, ... }:
    {
      options.security.atRestProtection.enable = lib.mkEnableOption "at-rest protection (LUKS root filesystem)";

      config = lib.mkIf config.security.atRestProtection.enable {
        # Classic (scripted) stage-1 initrd, inherited from the upstream default
        # rather than pinned: LUKS works through `boot.initrd.luks.devices` in
        # `_hardware-generated.nix` (machine truth, regenerated per host), and
        # the TPM/`HibernateLocation` tooling that wants systemd-initrd is unused
        # here — no TPM, no hibernation. Scripted initrd is deprecated upstream
        # and scheduled for removal in 26.11; when it lands this host moves to
        # `boot.initrd.systemd.enable = true` whether or not it wants the TPM
        # features, so the choice is recorded in ADR-0009 rather than pinned.
        assertions = [
          {
            assertion = lib.hasPrefix "/dev/mapper/" config.fileSystems."/".device;
            message = ''
              at-rest protection is enabled but the root filesystem is not a
              LUKS mapper device (${config.fileSystems."/".device}). This host
              is still plaintext; wipe and reinstall it with LUKS per the README
              before enabling at-rest protection.'';
          }
        ];
      };
    };
}
