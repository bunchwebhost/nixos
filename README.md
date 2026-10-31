# NixOS Flake - Bunch Webhost

This README describes the cluster as it's set up today. Its purpose and configuration will change, so if this file and the Nix files disagree, trust the Nix files.

## Hosts

| Host          | Role                          | k3s                   | Cluster IP | Extra storage                     |
| ------------- | ----------------------------- | --------------------- | ---------- | --------------------------------- |
| `twilight`    | Gateway (router, DHCP, DNS)   | server (cluster init) | 10.0.0.1   | `/mnt/storage1`, `/mnt/storage2`  |
| `fluttershy`  | Node                          | server                | 10.0.0.2   | `/mnt/storage1`                   |
| `rainbowdash` | Node                          | server                | 10.0.0.3   | none                              |
| `rarity`      | Node                          | agent                 | 10.0.0.4   | none                              |
| `pinkiepie`   | Node                          | agent                 | 10.0.0.5   | none                              |
| `applejack`   | Node                          | agent                 | 10.0.0.6   | none                              |

All six are x86_64 Intel machines that boot with UEFI and systemd-boot and use an ext4
root. The extra storage disks are mounted `nofail`, so a missing disk won't stop
boot.

## Networking

```
                    NBN
                     │
                     │ enp0s20f0u12   DHCP + IPv6 RA, default route
              ┌──────┴──────┐
 home LAN ────┤  twilight   │
   eno1       └──────┬──────┘
   DHCP, SSH only    │ enp0s20f0u9    10.0.0.1/24
   no routes/DNS     │                dnsmasq (DHCP + DNS), NAT out to NBN
                     │
              cluster switch
   ┌──────────┬──────┴─────┬──────────┬──────────┐
fluttershy rainbowdash  rarity    pinkiepie  applejack
 10.0.0.2   10.0.0.3   10.0.0.4   10.0.0.5   10.0.0.6
```

- **WAN:** the NBN link is twilight's only default route. No inbound ports are
  open on it.
- **Home LAN:** twilight takes a DHCP address from the home router but ignores
  its gateway, routes and DNS. The only thing this interface is for is SSH in.
- **Cluster:** twilight is `10.0.0.1` and runs dnsmasq. Nodes get fixed leases
  by MAC address (set in [router.nix](hosts/twilight/router.nix)). Other clients
  get an address from `10.0.0.10`–`10.0.0.254`. DNS is forwarded to Cloudflare
  (`1.1.1.1`, `1.0.0.1`) and the local domain is `bwh`, so nodes can reach each
  other as `<host>.bwh`. The cluster is IPv4-only.
- **Forwarding:** twilight forwards three kinds of traffic: from the cluster out
  to the WAN, return traffic for established connections, and k3s pod traffic.
  Pod traffic means anything arriving on `cni0` or `flannel.1`, plus anything
  from the cluster LAN headed to them. Nothing from the WAN is forwarded to
  pods, so NodePorts can't be reached from the internet. Nodes and the home LAN
  can't route to each other, so to reach a node from the home LAN you go through
  twilight. The exception is pods running on twilight itself. The `cni0` rule
  doesn't limit the outgoing interface, so those pods can reach the home LAN.

### Firewall

| Where                                     | Open                                                       |
| ----------------------------------------- | ---------------------------------------------------------- |
| twilight, WAN                             | nothing                                                    |
| twilight, home LAN                        | TCP 22                                                     |
| twilight, cluster                         | TCP/UDP 53, UDP 67, TCP 6443, 2379–2380, 10250, UDP 8472   |
| twilight, `cni0` (its own pods)           | TCP 6443, 10250                                            |
| k3s servers (fluttershy, rainbowdash)     | TCP 22, 6443, 2379–2380, 10250, UDP 8472                   |
| k3s agents (rarity, pinkiepie, applejack) | TCP 22, 10250, UDP 8472                                    |

The ports are used for DNS (53), DHCP (67), the k3s API server (6443),
etcd (2379 for clients, 2380 for peers), the kubelet (10250) and flannel VXLAN
(8472). twilight's k3s ports are opened in
[router.nix](hosts/twilight/router.nix). Each node opens its own ports in its
`k3s.nix`.

## Kubernetes (k3s)

Every host runs k3s, configured in `hosts/<host>/k3s.nix`. Three of them are
servers running embedded etcd, so the control plane keeps quorum if one server
goes down.

- **twilight** started the cluster (`clusterInit`). Its node IP and flannel
  interface are pinned to the cluster NIC (`10.0.0.1`, `enp0s20f0u9`).
  Otherwise k3s would pick the WAN interface, because that's where the default
  route is. The kubeconfig at `/etc/rancher/k3s/k3s.yaml` is readable by the
  `wheel` group instead of only root.
- **fluttershy** and **rainbowdash** are the other two servers.
- **rarity**, **pinkiepie** and **applejack** are agents.

Every node joins through `https://10.0.0.1:6443` with the shared token in
[secrets/k3s.yaml](secrets/k3s.yaml). Pod traffic between nodes runs over
flannel VXLAN on the cluster switch.

## Secrets

Secrets are encrypted with [sops](https://github.com/getsops/sops). On every
host, [sops-nix](https://github.com/Mic92/sops-nix) decrypts them during
activation; [flake.nix](flake.nix) adds it to each host's configuration. Each
host decrypts with an age key derived from its SSH ed25519 host key, so there
are no separate keys to copy around. [.sops.yaml](.sops.yaml) lists those keys
and which files each one can decrypt.

| File               | Contents              | Decryptable by |
| ------------------ | --------------------- | -------------- |
| `secrets/k3s.yaml` | `k3s-token`           | all six hosts  |

Replacing or reinstalling a host changes its host key, so its age key has to be
updated and the secrets re-encrypted. There's no personal key in `.sops.yaml`,
so run this on a host that can already decrypt the file, such as twilight:

```sh
# Get the new host's age key, then put it in .sops.yaml
ssh-keyscan -t ed25519 <host>.bwh | ssh-to-age

# Re-encrypt to the updated key list, decrypting with this host's own key
SOPS_AGE_KEY=$(sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key) \
  sops updatekeys secrets/k3s.yaml
```

## Layout

```
flake.nix                  # inputs; one nixosConfiguration per host, each with sops-nix
.sops.yaml                 # each host's age key and which secrets it can decrypt
secrets/
  k3s.yaml                 # sops-encrypted k3s join token
modules/
  common.nix               # shared by every host
  node.nix                 # cluster nodes: DHCP on en*, open SSH
hosts/
  twilight/
    default.nix
    router.nix             # interfaces, NAT, nftables forward chain, dnsmasq, k3s ports
    home.nix               # home-manager for liam (git with SSH commit signing)
    k3s.nix                # k3s server that initialises the cluster
    hardware-configuration.nix
  <node>/
    default.nix            # hostname, boot loader, imports
    k3s.nix                # k3s server or agent, plus its firewall ports
    hardware-configuration.nix
```

[common.nix](modules/common.nix) sets up the following on every host:

- **Nix:** flakes enabled, store auto-optimisation, weekly GC of anything older
  than 14 days, and `liam` as a trusted user.
- **Locale:** `Australia/Sydney` time zone and `en_AU.UTF-8`.
- **Networking:** systemd-networkd with an nftables firewall.
- **User:** `liam` in `wheel`, with one authorised SSH key.
- **SSH:** key-only, `liam` only, no root login. Each host opens port 22 on the
  interfaces it chooses.
- **Kernel and hardware:** latest kernel, redistributable firmware, `fstrim`
  and `smartd`.
- **Tools:** git, vim, curl, dnsutils, ethtool, tcpdump, pciutils,
  usbutils and fastfetch, plus age, sops, ssh-to-age and openssl for managing
  secrets.

## License

MIT. See [LICENSE](LICENSE).
