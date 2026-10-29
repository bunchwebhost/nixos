{ ... }:

{
  # Cluster switch; twilight hands out the address and DNS
  systemd.network.networks."10-cluster" = {
    matchConfig.Name = "en*";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    linkConfig.RequiredForOnline = "routable";
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
}
