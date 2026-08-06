{ self, ... }: {

  flake.nixosModules.printing = { pkgs, ... }: {
    services.printing = {
      enable = true;
      drivers = with pkgs; [
        cups-filters
        cups-browsed
      ];
    };

    hardware.sane = {
      enable = true;
      extraBackends = [ pkgs.sane-airscan ];
    };

    # Avahi lives here, system-wide `nssmdns4` and `openFirewall` included,
    # because both halves of this module discover their devices over mDNS:
    # cups-browsed finds printers, sane-airscan finds scanners. Nothing else in
    # the repo needs mDNS today, so a module named `printing` is its only
    # honest owner. A future consumer can declare `services.avahi.enable`
    # itself — `enable = true` merges, so a second declaration is not a
    # conflict.
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    # The scanner udev rules and the CUPS queues are only reachable by a user
    # in these groups, so membership belongs to the concern, not to the host.
    users.users.${self.lib.username}.extraGroups = [
      "scanner"
      "lp"
    ];

    environment.systemPackages = with pkgs; [
      simple-scan
    ];
  };
}
