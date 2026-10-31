{ config, ... }:

{
  sops.secrets.k3s-token.sopsFile = ../../secrets/k3s.yaml;

  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.sops.secrets.k3s-token.path;
    serverAddr = "https://10.0.0.1:6443";
  };

  networking.firewall = {
    allowedTCPPorts = [
      6443 # API server
      2379 # etcd clients
      2380 # etcd peers
      10250 # kubelet
    ];
    allowedUDPPorts = [ 8472 ]; # flannel VXLAN
  };
}
