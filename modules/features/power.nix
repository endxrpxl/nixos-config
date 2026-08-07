{ ... }:
{
  # Power policy: everything that decides how the machine spends energy and
  # how it stops. The seam against `desktop` is what the decision acts on —
  # this module powers the machine down (lid, thermal and runtime tuning); the
  # shell blanks and locks the screen. Both read the same
  # battery through upower, which is why upower stays next to noctalia rather
  # than moving here.
  #
  # Laptop-only in practice, and named for the capability rather than the
  # machine: a second battery-powered host would import this unchanged.
  #
  # This machine cannot hibernate, so every verb below is one the kernel will
  # accept. See docs/adr/0006-no-hibernation-while-a-secretmem-user-runs.md.
  flake.nixosModules.power =
    { ... }:
    {
      # Alder Lake thermal management. nixos-hardware's `common-cpu-intel`
      # does not bring this in, and without it the package throttles on the
      # firmware's blunt limits under sustained load. No conflict with
      # power-profiles-daemon: thermald acts on temperature, PPD on policy.
      services.thermald.enable = true;

      # Runtime power tuning for devices PPD's profiles do not reach. This is
      # the one setting here with a known bite: `--auto-tune` enables
      # autosuspend on USB devices indiscriminately, which classically
      # manifests as a keyboard, mouse or dock port that needs a jiggle after
      # a few seconds idle. Accepted knowingly — the symptom is recognisable
      # and this is one line to revert.
      powerManagement.powertop.enable = true;

      # Critical battery. Powering off loses unsaved work, and is still the
      # right action: the alternative is not hibernation, it is running the
      # cell flat and losing the same work with a deep discharge on top.
      services.upower.criticalPowerAction = "PowerOff";

      services.logind.settings.Login = {
        # A closed lid suspends, on battery and on mains alike.
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";

        # Docked to an external display, a closed lid means "use the other
        # screen", not "sleep".
        HandleLidSwitchDocked = "ignore";
      };
    };
}
