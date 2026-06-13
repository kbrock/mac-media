# mac-media (the server)

The basement Mac Mini. Catch-all for projects on the box that don't yet
have a bigger home, plus configuration and implementation decisions that
execute on the goals defined in `network.md`, `storage.md`, and `media.md`.

For the canonical service list and "what's running" see [../README.md](../README.md).
For the install runbook see [../server/mac-media-setup.md](../server/mac-media-setup.md).
The actual scripts live in [../server/](../server/).

## Hardware

- 2012 Intel Mac Mini, Fedora 43, wired ethernet only, mechanical HD.
- Reserved IP: 192.168.1.246.
- See [hardware.md](hardware.md) for the Servers table entry.

## What runs on it

| Service       | How       | Listens on |
|---------------|-----------|------------|
| nginx (RPM)   | systemd   | 80, 443    |
| landing (container nginx:alpine) | quadlet, user-mode | 8080 (host) → 80 (container) |
| jellyfin      | quadlet, user-mode, `Network=host` | 8096 |
| navidrome     | quadlet, user-mode, `Network=host` | 4533 |
| homeassistant | quadlet, user-mode, `Network=host` | 8123 |
| cockpit       | RPM       | 9090 (admin UI) |
| acme-sh       | system-mode quadlet, weekly timer | — (cron only) |

**Two nginx are intentional.** The RPM nginx on 80/443 is the reverse
proxy — terminates TLS, holds the cert, routes by `server_name`. The
container nginx (`landing.container`) is the application server for the
static landing page, isolated like every other app on the box. Keeping
proxy and app separate means the landing page is just another upstream,
not a special case in the reverse proxy config. Don't consolidate.

## Layout on disk

```
~/.config/systemd/user/                          # user systemd units
~/.config/containers/systemd/                    # user quadlets (HA, Jellyfin, etc.)
~/srv/<service>/                                 # bind-mount data
/etc/containers/systemd/                         # system quadlets (acme-sh)
/etc/systemd/system/                             # system units + timers (acme-sh.timer)
/etc/nginx/                                      # RPM nginx config
/etc/letsencrypt/live/home.thebrocks.net/        # cert (fullchain.pem, privkey.pem)
/etc/acme.sh/cloudflare.env                      # CF API token, chmod 600 root
/mnt/nas/{video,music}/                          # SMB mounts (read-only via guest)
```

## SSL / cert (implemented this session)

Executes the DNS plan from `network.md`. See `TODO.md` §1 for what remains.

- **Issuer**: Let's Encrypt, wildcard `*.home.thebrocks.net` + apex via
  Cloudflare DNS-01.
- **Tool**: acme.sh in a podman container (`docker.io/neilpang/acme.sh`).
- **Schedule**: weekly via systemd timer (`acme-sh.timer`). LE renews when
  ≤30 days from expiry; weekly gives ~4 attempts in the renewal window.
- **Reload**: `acme-sh.service` has `ExecStartPost=/usr/bin/systemctl reload nginx`
  (cheap no-op if cert unchanged). Chose this over a separate `nginx-reload.path`
  file watcher — synchronous and one fewer moving part.
- **Cert files**: installed at `/etc/letsencrypt/live/home.thebrocks.net/`
  via acme.sh `--install-cert`. Records install paths in acme.sh state so
  future renewals auto-install.
- **CF token format**: `/etc/acme.sh/cloudflare.env` must be plain
  `KEY=value` lines — no `export`, no quotes. `podman --env-file` parses
  Docker-style, not shell-style.

## System vs user quadlets

- **User-mode** (`~/.config/containers/systemd/`): the household services
  (HA, Jellyfin, Navidrome, landing). Run as kbrock. Standard pattern.
- **System-mode** (`/etc/containers/systemd/`): infrastructure that needs
  root (acme.sh writing to `/etc/letsencrypt/`). Sibling to nginx and
  firewalld, not a "service."

Quadlet does NOT process `.timer` files — only `.container` (and `.pod`,
`.network`, `.volume`, etc.). Timers go in `/etc/systemd/system/` as
regular systemd timers that trigger the quadlet-generated `.service`.

## SSO (planned)

Authelia at `auth.home.thebrocks.net`. OIDC clients for HA, Jellyfin,
Navidrome, Immich. Family user accounts. See `TODO.md` §2.

## Home automation (lives here for now)

HA quadlet uses `Network=host` for mDNS device discovery. Currently the
home-automation hub by default — if HA grows its own bucket someday, move
the device state and integration notes out. For now, HA is a mac-media
service; HA devices live in `hardware.md`; HA integration status lives in
`server-projects.md` backlog.

## Deploys (laptop → mac-media)

| What | Command | Destination |
|------|---------|-------------|
| Repo bundle (no creds) | `make setup` | `mac-media:server/` |
| Cloudflare cred | `make creds` | `mac-media:server/acme/cloudflare.env` |
| Landing HTML | `make landing` | `mac-media:srv/landing/` |
| User quadlets | `make quadlets` | `~/.config/containers/systemd/` + daemon-reload |
| nginx config | `make nginx` | `/etc/nginx/{nginx.conf,conf.d/home.conf}` + reload |
| System setup (interactive) | ssh; `./setup_mac.sh <section>` | various |
