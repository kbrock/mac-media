# Home Assistant - Basement Mac Mini ("mac-media")

Fedora 43 + Podman Quadlet on a 2012 Intel Mac Mini.

## Why these choices

| Decision          | Chose            | Over             | Why                                                        |
|-------------------|------------------|------------------|------------------------------------------------------------|
| Container runtime | Podman + Quadlet | k3s, docker      | Ships with Fedora. Systemd-native. No daemon. No curl-bash |
| Deployment        | Quadlet units    | RPMs, Helm, scp  | RPM is overkill for config files. Quadlet IS the packaging |
| Network mode      | Host             | Bridge           | HA needs mDNS/SSDP for device discovery on the LAN        |
| Storage           | Bind mount       | Named volume     | See the files on disk, back up via git                     |
| Secrets           | 1Password        | Vault            | Family already uses it. `op` CLI for scripts. Vault is overkill |

## Files

- [mac-media-setup.md](mac-media-setup.md) — server setup guide (Fedora, cockpit, podman)
- [linux-cheatsheet.md](linux-cheatsheet.md) — old command to new command reference
- `quadlet/` — podman container/volume definitions
- `ha-config/` — Home Assistant config (bind-mounted on server, backed up here)

## Deploy

```bash
scp quadlet/* mac-media:/etc/containers/systemd/
ssh mac-media 'systemctl daemon-reload && systemctl start homeassistant'
```

## Access

- Home Assistant: http://mac-media:8123
- Cockpit: https://mac-media:9090

## Integrations

- **iRobot Roomba j9+ (Wall-E)** — built-in integration, local MQTT. Password via `dorita980 getPasswordCloud` (cap.pw:0, local retrieval blocked on j-series)
- **Govee lights (x2)** — HACS `govee_lan_api`, enable LAN control in Govee app first
- **Bed** — (integrated, details TBD)
- **Ecobee v3** — TODO. Built-in integration, OAuth pin flow via HA UI. Unit is 14 years old, may be finicky
- **Car charger (Pulsar)** — TODO, need to confirm exact model
- **Emporia plugs (x4)** — TODO

## Rebuilding from scratch

1. Fresh Fedora install on the Mac Mini
2. Follow [mac-media-setup.md](mac-media-setup.md)
3. `git clone` this repo
4. Deploy quadlet files (see above)
5. Open :8123, re-add integrations
6. Restore HA backup if available
