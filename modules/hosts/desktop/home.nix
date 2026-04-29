{ self, ... }: {
  
  flake.homeModules.${self.username} = { ... }: {
    imports = [
      self.homeModules.desktop
    ];

    programs.bash = {
      enable = true;
      bashrcExtra = ''
        export SSH_AUTH_SOCK=${self.homeDir}/.bitwarden-ssh-agent.sock
      '';
    };

    home.stateVersion = "25.11";
  };
}