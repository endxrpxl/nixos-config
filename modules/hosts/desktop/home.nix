{ self, ... }: {

  flake.homeModules.${self.username} = { ... }: {
    imports = [
      self.homeModules.desktop
    ];

    programs.bash = {
      enable = true;
      bashrcExtra = ''
        export SSH_AUTH_SOCK=${self.homeDir}/.bitwarden-ssh-agent.sock
        export PATH="$HOME/.config/emacs/bin:$PATH"

        ip-fix () {
            sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
            sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
        }
      '';
    };

    home.stateVersion = "25.11";
  };
}
