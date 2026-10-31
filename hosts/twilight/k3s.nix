{ config, ... }:

{
  sops.secrets.k3s-token.sopsFile = ../../secrets/k3s.yaml;

  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.sops.secrets.k3s-token.path;
    clusterInit = true;
    # Default route is the WAN; keep k3s on the cluster switch (lanNic in router.nix)
    extraFlags = [
      "--node-ip=10.0.0.1"
      "--flannel-iface=enp0s20f0u9"
    ];
  };
}
