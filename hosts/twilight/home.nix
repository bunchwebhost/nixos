{ inputs, ... }:

{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.liam = {
      programs.git = {
        enable = true;
        signing = {
          format = "ssh";
          key = "~/.ssh/id_ed25519.pub";
          signByDefault = true;
        };
        settings = {
          user = {
            name = "Liam Bunch";
            email = "liam@liambunch.com";
          };
          init.defaultBranch = "main";
          pull.rebase = true;
        };
      };

      home.stateVersion = "26.05";
    };
  };
}
