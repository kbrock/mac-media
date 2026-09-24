# Network Decisions

## IoT discovery: dual-homed host, HA network=host pinned to DumbHome

Chose: mac-media dual-homed (BHome + DumbHome VLAN sub-interface). HA
runs `Network=host`, adapter pinned to the DumbHome interface only —
lets HA discover any WiFi/UDP/mDNS IoT device natively, no per-device
rules.

Considered and dropped: DNAT (per-device rule to rewrite discovery
packets — doesn't scale, UniFi doesn't route multicast cross-VLAN).
Linux bridge + Podman-attached container — dropped once host-network +
adapter-pin solved discovery on its own; also rootless Podman can't
attach to a host bridge without root.

## hub.home.thebrocks.net stays on 1.x

DNS/nginx routing unchanged — same hostname-match nginx pattern as
every other service. nginx proxies to the container's DumbHome IP
instead of localhost.

## Thread Border Router: skip for now

Not needed for WiFi-only Matter or plain-UDP devices — only for
Thread-only devices. Revisit at purchase of the first Thread-only
device. If needed: HA Connect ZBT-1/ZBT-2 + OTBR add-on (no Apple
ecosystem required).

## mDNS-discovered devices (future): UniFi's mDNS Proxy toggle

For ESPHome/Shelly-style mDNS discovery — not Govee-style raw UDP —
UniFi's built-in mDNS Proxy is correctly scoped for this, no DNAT
needed.

## DumbHome sub-interface gets its own DHCP hostname (mac-media2)

Both mac-media NICs sent the same DHCP hostname (`mac-media`), so
UniFi's local DNS served the DumbHome IP (`192.168.2.246`) for the bare
`mac-media` lookup instead of the primary one (`192.168.1.246`) —
`mac-media.home.thebrocks.net` (the static A record) was unaffected.
Fixed by setting `ipv4.dhcp-hostname mac-media2` on the `dumbhome`
connection, so the two interfaces register as distinct UniFi clients by
name, not just by MAC.

## Dual-homed host VLAN sub-interfaces get a cloned MAC

Real MAC on a second VLAN sub-interface collided with the host's
existing UniFi client entry (only one network's Fixed-IP/Override was
selectable). Fixed by hardcoding a mock MAC (`cloned-mac-address`) on
the sub-interface so UniFi treats it as a separate client.

## MQTT not used yet, but likely needed soon

Devices like Shelly/Tasmota/Zigbee2MQTT are MQTT-based — no
VLAN-crossing discovery problem, just a broker allow-rule. Not set up
yet, but expected as more devices are added.
