# Home Network Topology & Configuration

_Last updated: 2026-09-06_

Current state of the LAN, gear, and topology. For per-device inventory see
[hardware.md](hardware.md).

## ISP

- Verizon FiOS.
- FiOS battery: GS Yuasa PX12072 from 2010, beeping, needs replacement.
- Quirk: FiOS appears to ramp download speed when it detects a measurement test.

## House Layout

Center-entrance colonial, ~2,000 sq ft (built 2005), fairly standard/cookie-cutter
layout.

```
                          2ND FLOOR
        ┌───────────────┬───────────────┬───────────────┐
        │  Kid Bedroom 1 │   Hallway     │  Kid Bedroom 2 │
        │                │  [U6+ AP]     │                │
        │                │  (ceiling,    │                │
        │                │   central)    │                │
        └───────────────┴───────┬───────┴───────────────┘
                                 │ staircase (open)
                          ┌──────┴──────┐
                          │Master Bedroom│
                          └─────────────┘

                          1ST FLOOR
        ┌───────────────┬───────────────┬───────────────┐
        │    Office      │   Staircase / │  Dining Room   │
        │  [FlexHD AP]   │    Hallway    │ (front corner, │
        │  (bookshelf,   │  (coat closet │  under Master) │
        │  eye level,    │   off hallway)│                │
        │  front side)   │               │                │
        ├───────────────┴───────────────┴───────────────┤
        │  Living Room (back, facing)  │  Kitchen (back)  │
        │                               │  Bathroom (back  │
        │                               │  corner)         │
        └───────────────────────────────────────────────┘

                          BASEMENT
        ┌───────────────────────────────────────────────┐
        │  UCG Max (gateway/controller, "Fort Knox")      │
        │  USW Lite 16 (switch)                           │
        └───────────────────────────────────────────────┘

                        ATTIC / 3RD FLOOR
        ┌───────────────────────────────────────────────┐
        │  USW Flex (outdoor-rated switch — attic runs    │
        │  hot/cold via open soffit, standard switch      │
        │  wasn't a good fit here)                        │
        └───────────────────────────────────────────────┘
```

**AP placement notes:**
- **FlexHD** sits in the office at eye-level (standing), on a mostly-open wood
  bookshelf with a metal frame. This is the room we care about most day-to-day.
- **U6+** is ceiling-mounted in the central 2nd floor hallway, right outside the
  two kids' bedrooms, near the top of an open staircase down to the 1st floor.
- FlexHD's signal reaching the dining room has to pass through an interior wall,
  a coat closet, the hallway, and the staircase wall — several obstructions.
  Not a problem area currently, just useful context if dining-room coverage is
  ever revisited.

## Wired Topology

```
UCG Max (basement, "Fort Knox" — gateway + controller)
  │
  └── USW Lite 16 (basement switch)
        │
        ├── FlexHD (1st floor, office) — PoE
        │
        └── USW Flex (attic/3rd floor) — PoE
              │
              └── U6+ (2nd floor, central hallway ceiling) — PoE
```

USW Flex was added specifically to avoid a single long run from
basement → attic → 2nd floor, and because the attic's temperature swings
(open soffit) made an outdoor-rated switch the safer choice there.

## Equipment Inventory

| Device | Role | Status |
|---|---|---|
| UCG Max | Gateway / controller, "Fort Knox" (basement) | In use |
| USW Lite 16 | Switch (basement) | In use |
| USW Flex | Switch (attic/3rd floor, outdoor-rated) | In use |
| FlexHD | AP (1st floor, office) | In use |
| U6+ | AP (2nd floor, central hallway) | In use |
| Unifi Flex Mini | Switch | Unused (was printer) |
| FiOS gateway (CR1000A, fw 3.1.0.21) | ISP-provided gateway | Idle — Unifi handles routing |

## Cabling

- Ethernet runs throughout house, but **mixed T568A and T568B** (electrician
  vs user). Some ports don't work until standardized. Punchdown fix only.
- Office has 2 ethernet plugs wired T568B; user uses T568A. Repunch needed.
- Levitron patch panel: wires too short, cleanup pending.
- 3 telephone wires at patch panel: 1 fax (unused), 1 house phone, 1 unknown.

## Networks

- **BHome** (main) — `192.168.1.0/24`. Primary devices, full roaming/steering
  features enabled.
- **DumbHome** (IoT) — `192.168.2.0/24`, 2.4GHz and 5GHz. Split off separately
  specifically to allow more aggressive/non-backward-compatible roaming
  settings on the main network without breaking older or cheap IoT gear.
  Isolated from the main LAN (traffic does not pass freely between subnets).

### Device placement

- Staying on main LAN / default: printer, Roku.
- Not on the network at all: Samsung TV.
- Traffic direction per device (matters for firewall rule design):
  most devices are HA → internet (cloud API, no direct LAN traffic to
  the device). Roku is smart → dumb. Govee is smart → dumb and
  dumb → smart (UDP).
- See [hardware.md](hardware.md#home-automation) for per-device notes
  (Govee LAN discovery, Ecobee cloud dependency).

### UniFi gotchas when moving a device to a new network

- Moving a device with a static IP to a different network: uncheck
  "static" first, then change the network, or it keeps the old
  (now-invalid-range) IP.
- When you check the static-IP box, UniFi pre-fills the field with the
  device's *old* IP, not its current one — easy to accidentally re-pin
  the wrong address if you don't overwrite it.
- After reassigning a device to a new network, UniFi can keep serving
  its old (now out-of-range) IP — no "reprovision" action clears this.
  "Forget"-ing the device alone doesn't fix it. What works: on the
  network the device is moving *from* (e.g. Default), turn off
  auto-scale on the IP range, change the top of the range (any change,
  e.g. `.254` → `.253`), wait ~20 seconds for it to refresh, then turn
  auto-scale back on. This forces UniFi to drop the stale lease/cache.
  Reconnect the device and it picks up a correct IP in the new range.

### Govee: native LAN discovery

Built-in Govee Light Local integration.

### Dual-homed host on two VLANs (mac-media)

HA network discovery is pinned to the DumbHome interface (second
interface on mac-media, DumbHome VLAN, set up in `setup_mac.sh`), not
the default adapter.

## Current RF Configuration

### FlexHD (1st floor, office)
| Setting | Value |
|---|---|
| 2.4GHz | Channel 6, 20MHz, WiFi 4, 2x2, Power: **Low** |
| 5GHz | Channel 36, 80MHz, WiFi 5, 4x4, Power: **Medium** |
| Minimum RSSI | 2.4GHz: -72dBm, 5GHz: -75dBm |
| Observed avg signal | 2.4GHz: ~-49dBm, 5GHz: ~-65dBm |
| Observed interference | 2.4GHz: ~9.3%, 5GHz: ~0% |

Note: 5GHz power was dropped from High → Medium and client count on FlexHD
*increased* significantly — likely receiver overload / self-interference from
being very close to clients in the same room at high power. Don't push this
back up without a specific reason.

### U6+ (2nd floor, central hallway)
| Setting | Value |
|---|---|
| 2.4GHz | Channel 11 (manual), Power: **Medium** |
| 5GHz | Channel 161 (manual), 80MHz, Power: **Medium** |
| Minimum RSSI | 2.4GHz: -72dBm, 5GHz: -75dBm |
| Handoff Suggestion (802.11v) threshold | 5GHz: -70dBm |
| Observed avg signal | 2.4GHz: ~-56dBm, 5GHz: ~-66dBm |
| Observed interference | 2.4GHz: ~2.7%, 5GHz: ~0% |

Channels chosen deliberately: 2.4GHz (6 / 11) and 5GHz (36 / 161) are
non-overlapping between the two APs.

### BHome vs. DumbHome (IoT network) — Roaming & Behavior

| Setting | BHome (main) | DumbHome (IoT) |
|---|---|---|
| Fast Roaming (802.11r) | On | Off |
| Handoff Suggestions (802.11v) | On (5GHz threshold -70dBm) | — |
| Band Steering | On | — |
| BSS Transition | On (legacy toggle, predates 802.11v setting above) | — |

### DumbHome (IoT network) — other settings
| Setting | Value |
|---|---|
| Force WiFi 4 mode | Off |
| Lock 2.4GHz to Channel 6 | Off |
| IoT Optimization toggles | All off |

## Key Decisions & Rationale

- **Don't over-tighten RSSI thresholds** once signal/interference numbers look
  good — the good numbers are a sign the system is working, not an invitation
  to push further and risk kicking healthy connections.

## DNS plan

- Local DNS served by UCG Max (`fortknox`, 192.168.1.1).
- DHCP-pushed search domain: `home.thebrocks.net`.
- **No wildcard DNS record.** Explicit A records only:
  `{hub,movies,music,photos,auth,mac-media}.home.thebrocks.net` → mac-media
  (192.168.1.246), plus `fortknox.home.thebrocks.net` → itself (192.168.1.1).
- Public DNS at Cloudflare hosts only ACME TXT records (transient).

Wildcard DNS was tried but all unknown domains redirected to mac-media.

### Setup (UCG Max, manual via UniFi Network UI)

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

- **Local DNS only** for `*.home.thebrocks.net`. UCG Max resolves; nothing
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

## Backlog

- **Local NTP server** — capture all NTP traffic and route to our own server.
  Reduces IoT chatter, more control over time sync.
- **Find uses for Emporia smart plugs (x4)** — currently unused.
