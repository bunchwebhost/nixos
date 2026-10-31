{ config, ... }:

{
  sops.secrets.k3s-token.sopsFile = ../../secrets/k3s.yaml;

  services.k3s = {
    enable = true;
    role = "agent";
    tokenFile = config.sops.secrets.k3s-token.path;
    serverAddr = "https://10.0.0.1:6443";
  };

  networking.firewall = {
    allowedTCPPorts = [ 10250 ]; # kubelet
    allowedUDPPorts = [ 8472 ]; # flannel VXLAN
  };
}
