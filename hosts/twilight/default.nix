{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./router.nix
    ./home.nix
    ./k3s.nix
    ../../modules/common.nix
  ];

  networking.hostName = "twilight";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";
}
