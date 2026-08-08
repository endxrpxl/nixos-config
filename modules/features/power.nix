{ ... }:
{
  # Power policy: everything that decides how the machine spends energy and
  # how it stops. The seam against `desktop` is what the decision acts on —
  # this module powers the machine down (charge thresholds, lid, thermal and
  # runtime tuning); the shell blanks and locks the screen. Both read the same
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
      # Charge thresholds. The battery stops at 80% and does not resume until
      # it falls below 60%, so a machine left plugged in sits at a healthier
      # state of charge and cycles rarely. The 20-point band is the point: a
      # narrow one would trickle the cell back to full over and over.
      #
      # BAT0 is hardcoded. This machine has exactly one battery and two USB-C
      # source PSUs that must not be touched, and a threshold that silently
      # stops applying is worse than one that shows up red in `systemctl
      # status` — hence `set -eu` and a bare redirect, which fails the unit if
      # the path is gone rather than skipping it.
      systemd.services.battery-charge-thresholds = {
        description = "Apply battery charge thresholds";

        # Boot does not go through udev for this. The rule below matches under
        # `udevadm test` and fires under a manual trigger, but BAT0 comes out
        # of coldplug with no `TAGS=` and no `.device` unit, so the tag alone
        # left this unit dead for its entire life before 2026-08-08. The
        # target is what makes it run; the rule is now only for hotplug.
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        # The kernel rejects a start threshold at or above the current stop
        # threshold, so the order is not free: dropping start to 0 first makes
        # the following two writes valid from any prior state, including one a
        # human set by hand.
        script = ''
          set -eu
          bat=/sys/class/power_supply/BAT0
          echo 0 > "$bat/charge_control_start_threshold"
          echo 80 > "$bat/charge_control_end_threshold"
          echo 60 > "$bat/charge_control_start_threshold"
        '';
      };

      # Hotplug only. `add` does fire for a battery inserted into a running
      # machine, and re-running the unit is how the numbers get reapplied to a
      # cell that arrives with the vendor's defaults. It is not load-bearing
      # for boot — see the `wantedBy` above for why that was a mistake.
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="power_supply", KERNEL=="BAT0", TAG+="systemd", ENV{SYSTEMD_WANTS}+="battery-charge-thresholds.service"
      '';

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
