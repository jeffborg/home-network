# netboot.xyz

UEFI network boot for the LAN. The iPXE menu is fetched from upstream at boot time —
there is no local asset mirror.

- Web UI (menu editor): `netboot.${BASE_DOMAIN}` — **no authentication**, same as every
  other ingress in this cluster. It controls what machines boot.
- Boot path: `netbootxyz-boot`, UDP/69 (TFTP) + TCP/80 (nginx). Not behind the ingress,
  so a PXE boot never depends on DNS or TLS. MetalLB allocates the address from the pool
  and external-dns publishes it as `boot.netboot.${BASE_DOMAIN}`.

## Editing menus and hosting install configs

The single 1Gi PVC is mounted three ways:

| On the volume | Seen as | Purpose |
|---|---|---|
| `/` | netbootxyz `/config` | menus, nginx conf - served over **TFTP** |
| `/http` | netbootxyz `/assets` | served over **HTTP** on the boot address, at `/` |
| `/code-server` | code-server `/config` | the editor's own settings |

`code.netboot.${BASE_DOMAIN}` runs code-server with the whole volume open at `/netboot`,
so menus and anything you want to serve over HTTP are editable in a browser. It has
**no authentication** - a root shell on the cluster network for anyone on the LAN.

### Unattended installs

netboot.xyz probes for these on every boot; "not found" in the TFTP log is normal:

- `menus/autoexec.ipxe` - runs before the menu, for everyone
- `menus/local-vars.ipxe` - global variable overrides
- `menus/MAC-<mac>.ipxe` - per-host, in both `aabbcc...` and `aa-bb-cc-...` forms

A per-host file is the way to auto-install one machine while everything else still gets
the normal menu. Chain the Debian installer and point it at a preseed dropped in `/http`:

```
#!ipxe
set base http://deb.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64
kernel ${base}/linux
initrd ${base}/initrd.gz
imgargs linux auto=true priority=critical url=http://<boot addr>/preseed.cfg interface=auto DEBIAN_FRONTEND=text ---
boot || shell
```

**Delete the per-MAC file once the install is done** - a machine set to network-boot
first will otherwise wipe and reinstall itself on every reboot.

## UniFi

Settings → Networks → LAN → DHCP → Network Boot:

- Server: the address MetalLB gave `netbootxyz-boot` (`kubectl -n network get svc netbootxyz-boot`)
- Filename: `netboot.xyz.efi`

UEFI only, and Secure Boot must be **off** on the client. Legacy BIOS would need
`netboot.xyz.kpxe` plus proxy-DHCP, which is not set up here.

## Required node prep: the TFTP conntrack helper

TFTP sends its `DATA` from a *new* ephemeral source port. That is a pod-initiated flow
that no conntrack entry covers, so flannel masquerades it to the node's own address and
the client sees the reply coming from somewhere other than the VIP it addressed. PXE
firmware drops that, and the boot hangs.

`nf_conntrack_tftp` / `nf_nat_tftp` fix it: the helper registers an expectation for the
reply and reverse-NATs it back to the VIP. Kernels >= 4.7 no longer assign helpers
automatically, so the helper also has to be attached explicitly in the raw table.

Run this on **every** node so the pod — and with `externalTrafficPolicy: Local`, the VIP
— stays free to move.

```bash
# load now + at boot
sudo modprobe nf_conntrack_tftp nf_nat_tftp
printf 'nf_conntrack_tftp\nnf_nat_tftp\n' | sudo tee /etc/modules-load.d/tftp-conntrack.conf

# attach the helper to UDP/69, and keep it attached across reboots
sudo tee /etc/systemd/system/tftp-conntrack-helper.service >/dev/null <<'EOF'
[Unit]
Description=Attach the TFTP conntrack helper to UDP/69 (netboot.xyz)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'iptables -t raw -C PREROUTING -p udp --dport 69 -j CT --helper tftp 2>/dev/null || iptables -t raw -A PREROUTING -p udp --dport 69 -j CT --helper tftp'

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now tftp-conntrack-helper

# check
lsmod | grep -E 'nf_(conntrack|nat)_tftp'
sudo iptables -t raw -S PREROUTING | grep 'dport 69'
```

The rule has to land in the same backend k3s uses, so check before adding it:

```bash
update-alternatives --display iptables
```

The ansible `k3s` role points managed nodes at `iptables-legacy`, while a fresh
Debian-family install defaults to nft — so don't assume, and use the host's own
`iptables` binary (not one from a container) so it follows whatever the alternative is
set to. If a kernel rejects `-j CT --helper`, the older knob is
`net.netfilter.nf_conntrack_helper=1` in `/etc/sysctl.d/`.

Last resort if the helper cannot be made to work: set `defaultPodOptions.hostNetwork: true`
on the HelmRelease and point UniFi at that node's own address — replies then come from
the address the client dialled. Costs host ports 69/80/3000 and the portability.

## Verifying

```bash
kubectl -n network get svc netbootxyz-boot   # EXTERNAL-IP from the pool, 69/UDP + 80/TCP
curl -s http://<that address>/ | head        # nginx index
tftp <that address> -c get netboot.xyz.efi   # exercises the NAT path above
```
