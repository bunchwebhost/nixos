# NixOS Flake - Bunch Webhost

This README describes the cluster as it's set up today. Its purpose and configuration will change, so if this file and the Nix files disagree, trust the Nix files.

## Hosts

| Host          | Role                          | Cluster IP | Extra storage                     |
| ------------- | ----------------------------- | ---------- | --------------------------------- |
| `twilight`    | Gateway (router, DHCP, DNS)   | 10.0.0.1   | `/mnt/storage1`, `/mnt/storage2`  |
| `fluttershy`  | Node                          | 10.0.0.2   | `/mnt/storage1`                   |
| `rainbowdash` | Node                          | 10.0.0.3   | none                              |
| `rarity`      | Node                          | 10.0.0.4   | none                              |
| `pinkiepie`   | Node                          | 10.0.0.5   | none                              |
| `applejack`   | Node                          | 10.0.0.6   | none                              |

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
- **Forwarding:** traffic is forwarded only from the cluster out to the WAN,
  plus the return traffic for those connections. The home LAN and the cluster
  can't route to each other, so to reach a node from the home LAN you go through
  twilight.

### Firewall

| Where                    | Open                                 |
| ------------------------ | ------------------------------------ |
| twilight, WAN            | nothing                              |
| twilight, home LAN       | TCP 22                               |
| twilight, cluster        | TCP/UDP 53 (DNS), UDP 67 (DHCP)      |
| nodes                    | TCP 22                               |

## Layout

```
flake.nix                  # inputs and one nixosConfiguration per host
modules/
  common.nix               # shared by every host
  node.nix                 # cluster nodes: DHCP on en*, open SSH
hosts/
  twilight/
    default.nix
    router.nix             # interfaces, NAT, nftables forward chain, dnsmasq
    home.nix               # home-manager for liam (git with SSH commit signing)
    hardware-configuration.nix
  <node>/
    default.nix            # hostname, boot loader, imports
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
  usbutils and fastfetch.
