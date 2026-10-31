{ config, ... }:

{
  sops.secrets.k3s-token.sopsFile = ../../secrets/k3s.yaml;

  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = config.sops.secrets.k3s-token.path;
    clusterInit = true;
    extraFlags = [
      "--node-ip=10.0.0.1"
      "--flannel-iface=enp0s20f0u9"
      "--write-kubeconfig-mode=0640"
      "--write-kubeconfig-group=wheel"
    ];
  };
}
