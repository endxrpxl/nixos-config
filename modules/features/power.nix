{ ... }:
{
  # Power policy: everything that decides how the machine spends energy and
  # how it stops. The seam against `desktop` is what the decision acts on —
  # this module powers the machine down (charge thresholds, lid, hibernation,
  # thermal and runtime tuning); the shell blanks and locks the screen. Both
  # read the same battery through upower, which is why upower stays next to
  # noctalia rather than moving here.
  #
  # Laptop-only in practice, and named for the capability rather than the
  # machine: a second battery-powered host would import this unchanged.
  #
  # Deliberately not TLP. TLP would supply the charge thresholds below, but
  # enabling it applies its *entire* default policy — disk APM, USB
  # autosuspend, wifi power save, governor, runtime PM — and then contends
  # with power-profiles-daemon over the governor, EPP and platform_profile on
  # every AC transition. nixpkgs only asserts against `services.tlp.pd`, so
  # that pairing evaluates green and fights at runtime. The two sysfs writes
  # below are the whole of what was actually wanted.
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

      # udev rather than a `wantedBy` on a boot target, because `add` fires for
      # the battery on every boot *and* on hotplug — one rule covers both, so
      # the unit above stays the single place the numbers live.
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

      # Nothing below hibernates, and that is not an oversight — this machine
      # cannot. The kernel gates hibernation on `hibernation_available()`, which
      # is false while any process holds a `memfd_secret`, because writing an
      # image would put secret memory on disk and defeat the point of it.
      # Bitwarden holds one from autostart, with the vault still locked, so
      # `/sys/power/disk` reads `[disabled]` in every session and logind reports
      # `CanHibernate = na`.
      #
      # This matters more than a missing feature, which is why it is stated
      # here rather than left to the ADR: logind does *not* fall back when a
      # configured action is unavailable. It logs "operation not supported" and
      # does nothing. A lid set to `suspend-then-hibernate` on this machine is
      # therefore a lid that does nothing at all — a laptop left running in a
      # bag — and `criticalPowerAction = "Hibernate"` is a battery that runs
      # flat in silence. Every verb below is one the kernel will accept.
      #
      # See docs/adr/0006-no-hibernation-while-a-secretmem-user-runs.md, which
      # records what would have to change to get hibernation back.

      # Critical battery. Powering off loses unsaved work, and is still the
      # right action: the alternative is not hibernation, it is running the
      # cell flat and losing the same work with a deep discharge on top.
      # `HybridSleep`, the upstream default, is doubly wrong here — it needs the
      # hibernation this machine lacks, and it is a lid strategy rather than a
      # critical-battery one, staying in RAM on a cell that is about to die.
      services.upower.criticalPowerAction = "PowerOff";

      services.logind.settings.Login = {
        # A closed lid suspends, on battery and on mains alike. There is no
        # power-source distinction left to draw: `suspend-then-hibernate` was
        # the reason to have one, and it is unavailable.
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";

        # Docked to an external display, a closed lid means "use the other
        # screen", not "sleep".
        HandleLidSwitchDocked = "ignore";

        # `IdleAction` is deliberately unset. logind applies it identically on
        # mains and on battery, and an idle timeout that suspends a plugged-in
        # machine mid-build is worse than none. Idling belongs to whatever can
        # see the power source and the session — the shell — and it is the
        # shell's business anyway once the screen is involved.
      };
    };
}
