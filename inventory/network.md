# Home Network

Current state of the LAN, gear, and isolation goals.
For per-device inventory see [hardware.md](hardware.md).

## ISP

- Verizon FiOS.
- FiOS gateway (CR1000A, fw 3.1.0.21) sits idle. Unifi handles routing.
- FiOS battery: GS Yuasa PX12072 from 2010, beeping, needs replacement.
- Quirk: FiOS appears to ramp download speed when it detects a measurement test.

## Gear

| Device                | Role                       | Status                       |
|-----------------------|----------------------------|------------------------------|
| UDM (original "pill") | Router / gateway / AP      | `fortknox` at 192.168.1.1. UCG-Max replacement on hold |
| Unifi AC LR           | AP                         | Replace with **U6+** (first priority) |
| Unifi FlexHD          | AP                         | **Drop** — overheats. Tentative replacement: UK-Ultra |
| Unifi USW Lite 16 PoE | Switch (main)              | Keep                         |
| Unifi USW Flex (5pt)  | Switch (attic)             | Keep                         |
| Unifi Flex Mini       | Switch                     | Unused (was printer)         |

## Replacement priority

1. **U6+** — replaces AC LR. First buy.
2. **UK-Ultra** — replaces FlexHD. Tentative.
3. **UCG-Max** — replaces UDM. On hold; don't push.

Pricing (Micro Center): UCG-Max + U6+ together ~$360. UK-Ultra ~$89.

## Cabling

- Ethernet runs throughout house, but **mixed T568A and T568B** (electrician
  vs user). Some ports don't work until standardized. Punchdown fix only.
- Office has 2 ethernet plugs wired T568B; user uses T568A. Repunch needed.
- Levitron patch panel: wires too short, cleanup pending.
- 3 telephone wires at patch panel: 1 fax (unused), 1 house phone, 1 unknown.

## DNS plan

- Local DNS served by UDM (`fortknox`, 192.168.1.1).
- DHCP-pushed search domain: `home.thebrocks.net`.
- **No wildcard DNS record.** Explicit A records only:
  `{hub,movies,music,photos,auth,mac-media}.home.thebrocks.net` → mac-media
  (192.168.1.246), plus `fortknox.home.thebrocks.net` → itself (192.168.1.1).
- Public DNS at Cloudflare hosts only ACME TXT records (transient).

Wildcard DNS was tried but all unknown domains redirected to mac-media.

### Setup (UDM, manual via UniFi Network UI)

1. Settings → Networks → Your LAN → set **Domain Name** = `home.thebrocks.net`.
2. Settings → Policy Engine → DNS → Static DNS Entries → Create one A record
   per entry above.
3. Verify from a LAN device:
   ```
   dig @192.168.1.1 hub.home.thebrocks.net
   ```
   Returns `192.168.1.246`.

### Goal: no public records for internal services

Internal services (Jellyfin, HA, Navidrome, Immich, etc.) should not
appear in public DNS. This drives two decisions:

- **Local DNS only** for `*.home.thebrocks.net`. UDM resolves; nothing
  publicly exposes the LAN IP.
- **ACME DNS-01** (not HTTP-01) for cert issuance. DNS-01 only requires
  brief `_acme-challenge.*` TXT records during renewal, then deletes
  them. HTTP-01 would require opening port 80 on the public internet to
  prove control — exact opposite of the goal.

### Cert distribution

Wildcard `*.home.thebrocks.net` is issued on mac-media via certbot
(Cloudflare DNS-01) and pushed to LAN devices on renewal via deploy
hook (`server/certbot/push-cert-diskstation.sh`).

- **diskstation** — done. Pipes tar to `~/install-cert.sh` via SSH, reloads nginx.
- **fortknox** — TODO. Tool: `ubios-cert` (community).

### Browser quirk for bare names

Chrome treats a single-word URL (`movies`) as a search query, not a
hostname. Workaround: type `movies/` (trailing slash) the first time —
Chrome treats `name/` as a hostname. After first visit, autocomplete
remembers. Safari and Firefox usually resolve directly.

## Constraints / rules

- Network has felt slow. Unclear if NAS slowness is NAS or network.
  Resolve after AP replacement, not before.
- Don't recommend more network gear/services until U6+ lands.

## Backlog

- **IoT VLAN** — isolate Roku, Govee lights, Ecobee, printer, bed, Samsung TV.
  Samsung TV phones home aggressively (email on every power-on); don't trust
  its built-in apps. Mac's "scan local network" prompt is related.
- **Local NTP server** — capture all NTP traffic and route to our own server.
  Reduces IoT chatter, more control over time sync.
