{ ... }: {
  flake.nixosModules.easyroam =
    { pkgs, ... }:

    # easyroam on NixOS: declarative NM profile + renewal script + expiry reminder.
    #
    # First time / every renewal:
    #   1. download a new PKCS12 from https://www.easyroam.de ("Manuelle Optionen" -> PKCS12)
    #   2. sudo easyroam-renew ~/Downloads/<date>.p12
    #
    # Import this file in configuration.nix:  imports = [ ./easyroam.nix ];
    # Requires networking.networkmanager.enable = true;

    let
      stateDir = "/etc/easyroam";

      # Extracts cert/key/CA from the p12, validates, swaps files in atomically,
      # updates the identity and reloads the NM profile.
      easyroam-renew = pkgs.writeShellApplication {
        name = "easyroam-renew";
        runtimeInputs = with pkgs; [
          openssl
          coreutils
          gnused
          systemd
          networkmanager
        ];
        text = ''
          if [ "$(id -u)" -ne 0 ]; then
            echo "Run as root: sudo easyroam-renew <file.p12>" >&2
            exit 1
          fi

          in="''${1:-}"
          if [ ! -f "$in" ]; then
            echo "Usage: sudo easyroam-renew <file.p12>" >&2
            exit 1
          fi

          dir=${stateDir}
          pw=pkcs12   # password the extracted private key is re-encrypted with
          mkdir -p "$dir"
          tmp=$(mktemp -d "$dir/.new.XXXXXX")
          trap 'rm -rf "$tmp"' EXIT

          # easyroam p12 files use legacy encryption; OpenSSL 3 needs -legacy
          p12() { openssl pkcs12 -legacy "$@" 2>/dev/null || openssl pkcs12 "$@" 2>/dev/null; }

          if ! p12 -in "$in" -passin pass: -info -noout >/dev/null; then
            echo "ERROR: not a valid easyroam PKCS12 file." >&2
            exit 1
          fi

          p12 -in "$in" -passin pass: -clcerts -nokeys -out "$tmp/easyroam_client_cert.pem"
          p12 -in "$in" -passin pass: -nocerts -passout pass:"$pw" -out "$tmp/easyroam_client_key.pem"
          p12 -in "$in" -passin pass: -cacerts -nokeys -out "$tmp/easyroam_root_ca.pem"

          if ! openssl x509 -in "$tmp/easyroam_client_cert.pem" -noout -checkend 0 >/dev/null; then
            echo "ERROR: this certificate is already expired." >&2
            exit 1
          fi

          # Identity = CN of the client cert (serial@easyroam.<realm>), NOT the pairwise ID
          cn=$(openssl x509 -in "$tmp/easyroam_client_cert.pem" -noout -subject -nameopt RFC2253 \
                 | sed -n 's/.*CN=\([^,]*\).*/\1/p')
          case "$cn" in
            *@*) ;;
            *)
              echo "ERROR: unexpected CN '$cn' (expected serial@realm). Compare with the" >&2
              echo "'identity' file the DFN easyroam_extract.sh produces, nothing was changed." >&2
              exit 1
              ;;
          esac

          printf 'EASYROAM_IDENTITY=%s\n' "$cn" > "$tmp/identity.env"
          printf '%s\n' "$cn" > "$tmp/identity"

          chmod 0644 "$tmp/easyroam_client_cert.pem" "$tmp/easyroam_root_ca.pem" "$tmp/identity"
          chown root:wpa_supplicant "$tmp/easyroam_client_key.pem"
          chmod 0440 "$tmp/easyroam_client_key.pem"
          chmod 0600 "$tmp/identity.env"

          # swap in (only reached if everything above succeeded)
          for f in easyroam_client_cert.pem easyroam_client_key.pem easyroam_root_ca.pem identity identity.env; do
            mv -f "$tmp/$f" "$dir/$f"
          done

          systemctl restart NetworkManager-ensure-profiles.service
          nmcli connection reload

          echo "Installed. Identity: $cn"
          openssl x509 -in "$dir/easyroam_client_cert.pem" -noout -enddate
        '';
      };

      # Runs in the user session, so notify-send reaches the notification daemon
      # (Noctalia, mako, dunst, ... anything implementing org.freedesktop.Notifications).
      easyroam-expiry-check = pkgs.writeShellApplication {
        name = "easyroam-expiry-check";
        runtimeInputs = with pkgs; [
          openssl
          coreutils
          libnotify
        ];
        text = ''
          cert=${stateDir}/easyroam_client_cert.pem
          [ -r "$cert" ] || exit 0

          end=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
          end_ts=$(date -d "$end" +%s)
          now=$(date +%s)
          left=$(( end_ts - now ))
          day=$(date -d "$end" +%F)

          if [ "$left" -le 0 ]; then
            notify-send -a easyroam -u critical -i network-wireless-offline \
              "easyroam certificate expired" \
              "Expired on $day. Download a new .p12 and run: sudo easyroam-renew <file>"
          elif [ "$left" -le 604800 ]; then
            urgency=normal
            [ "$left" -le 172800 ] && urgency=critical
            notify-send -a easyroam -u "$urgency" -i network-wireless \
              "easyroam certificate expires soon" \
              "Valid until $day ($(( left / 86400 )) days left). Get a new .p12 from easyroam.de and run: sudo easyroam-renew <file>"
          fi
        '';
      };
    in
    {
      environment.systemPackages = [ easyroam-renew ];

      # State dir: cert/CA world-readable (so the user timer can check expiry), key root-only.
      # identity.env is created with a placeholder so the first rebuild doesn't fail
      # before easyroam-renew has run.
      systemd.tmpfiles.rules = [
        "d ${stateDir} 0755 root root -"
        "f ${stateDir}/identity.env 0600 root root - EASYROAM_IDENTITY=unset"
      ];

      # NM profile; identity is substituted from identity.env, so renewals
      # (new serial = new identity) need no rebuild.
      networking.networkmanager.ensureProfiles = {
        environmentFiles = [ "${stateDir}/identity.env" ];
        profiles.eduroam = {
          connection = {
            id = "eduroam";
            type = "wifi";
          };
          wifi = {
            ssid = "eduroam";
            mode = "infrastructure";
          };
          wifi-security.key-mgmt = "wpa-eap";
          "802-1x" = {
            eap = "tls";
            identity = "$EASYROAM_IDENTITY";
            altsubject-matches = "DNS:easyroam.eduroam.de";
            phase1-auth-flags = "256"; # 0x100, same as the DFN script
            ca-cert = "${stateDir}/easyroam_root_ca.pem";
            client-cert = "${stateDir}/easyroam_client_cert.pem";
            private-key = "${stateDir}/easyroam_client_key.pem";
            private-key-password = "pkcs12";
          };
          ipv4.method = "auto";
          ipv6.method = "auto";
        };
      };

      # Daily check (and 1 min after each login), catches up after suspend/off.
      systemd.user.services.easyroam-expiry = {
        description = "Notify when the easyroam certificate is about to expire";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${easyroam-expiry-check}/bin/easyroam-expiry-check";
        };
      };
      systemd.user.timers.easyroam-expiry = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          OnStartupSec = "1min";
          Persistent = true;
        };
      };
    };
}
