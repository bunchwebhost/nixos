{ pkgs, ... }:

{
  # Nix
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    trusted-users = [ "liam" ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Locale
  time.timeZone = "Australia/Sydney";
  i18n.defaultLocale = "en_AU.UTF-8";

  # General networking
  networking.useNetworkd = true;
  networking.useDHCP = false;
  networking.nftables.enable = true;
  networking.firewall.enable = true;

  # User
  users.users.liam = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGthUT7vcbg/MRejrwZWNi1u4yQQVZ+1GFaLo9QVHP73"
    ];
  };

  # SSH
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      AllowUsers = [ "liam" ];
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Hardware care
  hardware.enableRedistributableFirmware = true;
  services.fstrim.enable = true;
  services.smartd.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    fastfetch
    git
    vim
    curl
    dnsutils
    ethtool
    tcpdump
    pciutils
    usbutils
  ];
}
