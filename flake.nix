{
  description = "NixOS Flake - Bunch Webhost";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    {
      nixosConfigurations =
        nixpkgs.lib.genAttrs
          [
            "twilight"
            "fluttershy"
            "rainbowdash"
            "rarity"
            "pinkiepie"
            "applejack"
          ]
          (
            name:
            nixpkgs.lib.nixosSystem {
              specialArgs = { inherit inputs; };
              modules = [
                ./hosts/${name}
                inputs.sops-nix.nixosModules.sops
              ];
            }
          );

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    };
}
