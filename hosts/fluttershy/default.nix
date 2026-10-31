{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./k3s.nix
    ../../modules/common.nix
    ../../modules/node.nix
  ];

  networking.hostName = "fluttershy";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";
}
