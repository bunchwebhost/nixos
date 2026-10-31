{ ... }:

let
  # Direct NBN Connection
  wanNic = "enp0s20f0u12";

  # Cluster Switch
  lanNic = "enp0s20f0u9";
  lanAddress = "10.0.0.1";

  # Home Network
  homeNic = "eno1";
in
{
  systemd.network.networks."10-wan" = {
    matchConfig.Name = wanNic;
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };
    linkConfig.RequiredForOnline = "routable";
  };

  systemd.network.networks."20-home" = {
    matchConfig.Name = homeNic;
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    dhcpV4Config = {
      UseGateway = false;
      UseRoutes = false;
      UseDNS = false;
    };
    linkConfig.RequiredForOnline = "no";
  };

  systemd.network.networks."30-cluster" = {
    matchConfig.Name = lanNic;
    address = [ "${lanAddress}/24" ];
    networkConfig = {
      IPv6AcceptRA = false;
      ConfigureWithoutCarrier = true;
    };
    linkConfig.RequiredForOnline = "no";
  };

  networking.nat = {
    enable = true;
    externalInterface = wanNic;
    internalInterfaces = [ lanNic ];
  };

  networking.firewall.interfaces.${lanNic} = {
    allowedTCPPorts = [ 
      53
      6443
      2379
      2380
      10250
    ];
    allowedUDPPorts = [
      53
      67
      8472
    ];
  };
  networking.firewall.interfaces.cni0.allowedTCPPorts = [
    6443
    10250
  ];

  networking.firewall.interfaces.${homeNic}.allowedTCPPorts = [ 22 ];

  networking.nftables.tables.gateway-forward = {
    family = "inet";
    content = ''
      chain forward {
        type filter hook forward priority filter; policy drop;
        ct state established,related accept
        ct state invalid drop
        iifname "${lanNic}" oifname "${wanNic}" accept
        # k3s pod traffic; WAN can't reach pods through NodePorts
        iifname { "cni0", "flannel.1" } accept
        iifname "${lanNic}" oifname { "cni0", "flannel.1" } accept
      }
    '';
  };

  services.dnsmasq = {
    enable = true;
    settings = {
      interface = lanNic;
      bind-dynamic = true;
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;
      server = [
        "1.1.1.1"
        "1.0.0.1"
      ];
      domain = "bwh";
      local = "/bwh/";
      expand-hosts = true;
      dhcp-range = "10.0.0.10,10.0.0.254,12h";
      dhcp-option = [
        "option:router,${lanAddress}"
        "option:dns-server,${lanAddress}"
      ];
      # MAC,hostname,IP
      dhcp-host = [
        "9c:7b:ef:27:ac:0a,fluttershy,10.0.0.2"
        "e4:e7:49:51:46:7c,rainbowdash,10.0.0.3"
        "e4:e7:49:51:45:bd,rarity,10.0.0.4"
        "e4:e7:49:51:49:cd,pinkiepie,10.0.0.5"
        "e4:e7:49:51:4b:7a,applejack,10.0.0.6"
      ];
      dhcp-authoritative = true;
    };
  };
}
