# Wireless Access Point & Local File-Sharing Lab

## Objective
Configure a wireless access point or router, validate client connectivity, and test local file sharing. Router USB storage is optional and depends on the exact router model and firmware.

## Setup checklist
1. Record the router/AP model, firmware, LAN subnet, DHCP range and current configuration. Save a backup if supported.
2. Connect the AP in the intended mode. For a dedicated access point, connect LAN-to-LAN and disable its DHCP server if the main router already provides DHCP; avoid accidental double NAT.
3. Set a unique SSID and WPA2-AES or WPA3 security with a strong unique passphrase. Disable WPS if not needed; update firmware from the vendor.
4. Connect a client and check its IP address, subnet mask, default gateway and DNS. Test the gateway first, then DNS resolution and internet access if available.
5. Test coverage in several rooms; note signal level, band (2.4/5 GHz), channel congestion and any dead zones.
6. For local sharing, use a trusted computer as the file server and enable SMB sharing only on a Private/trusted network. Grant access to specific users; avoid Everyone/full-control permissions.
7. From a second client, test `\\HOSTNAME\ShareName` or `\\IPv4-address\ShareName`. Verify both read and write behavior according to the intended permissions.
8. If using router USB storage, consult the exact model's manual for supported SMB/FTP features. Prefer authenticated SMB or a VPN-supported access method; do not expose FTP, SMB or the router admin page directly to the internet.

## Troubleshooting sequence
- No IP address: check DHCP, Wi-Fi association, VLAN, and whether multiple DHCP servers exist.
- Can ping gateway but not use names: check DNS settings and name resolution.
- Can access internet but not local share: confirm both clients are on reachable subnets, Windows network profile is Private, File and Printer Sharing/firewall rules are appropriate, and credentials/permissions are correct.
- Router USB storage not visible: confirm USB drive format, router firmware feature support, sharing service enabled, and supported protocol. A USB port alone does not guarantee file-sharing support.

## Evidence to collect
- AP model and sanitized configuration screenshots
- Client `ipconfig /all` output (remove public IPs and sensitive details before publishing)
- Ping gateway and DNS lookup results
- File share access from a second client with personal data excluded
- Coverage observations and a short troubleshooting log
