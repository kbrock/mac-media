# mac-media

Personal home server config repo. Lives at the basement Mac Mini ("mac-media")
running Fedora.

## Why this exists

Two parallel goals:

1. **Run the household services** — Home Assistant, Jellyfin, Navidrome, landing
   page, future apps. Family-facing.
2. **Learn modern Linux / systemd / Podman.** This is hands-on practice for
   `systemctl`, `journalctl`, `firewall-cmd`, `nmcli`, quadlets, SELinux. Not
   just "make it work" — understand what each piece does. Resume claims are
   only as good as the practice behind them.

When in doubt, prefer the learnable path over the easy path. If a Synology
package would do it, do it on mac-media instead.

## Repo layout

```
.
├── CLAUDE.md              # this file
├── README.md              # human-facing overview
├── TODO.md                # active and backlogged tasks
├── linux-cheatsheet.md    # systemd / podman / firewalld notes
├── server/                # everything deployed to mac-media
│   ├── setup_mac.sh       # bootstrap fresh Fedora; idempotent, prompts before changes
│   ├── mac-media-setup.md # narrative runbook for fresh-machine bootstrap
│   ├── nginx/             # nginx.conf and conf.d/ files → /etc/nginx/
│   ├── nas-mounts/        # SMB mount units → /etc/systemd/system/
│   ├── quadlet/           # podman quadlet container definitions → ~/.config/containers/systemd/
│   └── seed/              # first-deploy data (groceries.md) → ~/srv/groceries/
├── tools/                 # laptop-side scripts
│   ├── encode_batch.rb    # MakeMKV + HandBrake DVD encoder
│   ├── music_diff.rb      # diff source music vs NAS, find missing
│   ├── find_n_dupes.rb    # find `Track.mp3` + `Track 1.mp3` duplicate pairs
│   └── resolve_n_dupes.rb # auto-resolve pairs by size-delta heuristic, punt ambiguous
├── hardware/              # non-mac-media physical projects (Pi GPIO, future ESP32 work)
└── inventory/             # device, photo, server-project, network, NAS lists
```

## Before recommending anything

Project state lives in repo files, not in auto-memory. Before recommending
a service, naming convention, or architecture decision, grep the files
listed under "Where state lives" below.

If the user mentions a service (Authelia, Immich, etc.), it's likely
already documented. Read the repo before treating it as a new decision.

**New todos:** committed work → `TODO.md`; uncommitted → the relevant
topic file below.

## Where state lives

- Hardware / devices → [inventory/hardware.md](inventory/hardware.md)
- Network gear → [inventory/network.md](inventory/network.md)
- NAS → [inventory/nas.md](inventory/nas.md)
- Running services → [README.md](README.md)
- Backlog (not committed) → [inventory/server-projects.md](inventory/server-projects.md)

**Runbook vs one-off.** A step belongs in the runbook (`server/mac-media-setup.md`)
if it recurs, e.g. adding a phone or Roku means enabling Quick Connect again. A
one-time cleanup that is finished once done (e.g. `tools/rename_fixes.rb`) is not
committed.

**Scripts are instructions too.** `server/*.sh` (e.g. `authelia-init.sh`,
`setup_mac.sh`) and `server/quadlet/*.container` encode setup/deploy
procedure just as much as any `.md` file — often more precisely, since
they're executable. When asked to update "instructions" or "docs" for
something, search these too, not just `*.md`. When a `.md` file describes
what a script does (e.g. `TODO.md`'s spec for `authelia-init.sh`), open
the actual script before editing the description — don't edit the
description in isolation.

## Deploy pattern

Use the `Makefile` targets — don't hand-roll scp/ssh. Check it before
suggesting a deploy command; it stays current with actual paths/filenames.

- `make nginx` — sync `server/nginx/`, test, reload (prompts for sudo password)
- `make authelia` — sync Authelia config + quadlet, restart
- `make <service>` (any of `$(QUADLET_SERVICES)`) — sync that service's quadlet, restart
- `make quadlets` — sync + restart all quadlets
- `make landing` — ship ../groceries (Roda app), build the image on mac-media, restart landing
- `make groceries-seed` — first deploy only: copy seed groceries.md to the server if absent
- `make nas-mounts` — sync NAS mount units, restart mounts
- `make diff` — dry-run preview of what would sync, before committing to a deploy
- `make revive` — reset+restart any `--user` unit stuck `failed` from crash-looping

See `Makefile` for the full target list and exact remote paths.

## Service / data layout on mac-media

```
~/.config/systemd/user/                 # systemd user unit files
~/.config/containers/systemd/           # podman quadlets (generates units above)
~/srv/<service>/                        # bind-mounted data per service
~/srv/groceries/                        # landing app data (groceries.md, master on server)
~/srv/jellyfin/{config,cache}/          # jellyfin
~/srv/homeassistant/config/             # home assistant
~/srv/navidrome/data/                   # navidrome
/mnt/nas/{video,music}/                 # NAS shares (SMB, read-only)
```

System-level (managed by RPM, not user):
```
/etc/nginx/                             # nginx (reverse proxy on :80)
/etc/systemd/system/mnt-nas-*.{mount,automount}  # NAS mount units
```

## Public repo considerations

This repo is intended to be public/git-friendly.

- **No secrets in tracked files.** Passwords, tokens, API keys go in untracked
  local files (`.gitignore`-ed) or environment variables.
- **Hostnames and LAN IPs are fine.** `mac-media`, `diskstation`, `192.168.1.x`
  appear and are not sensitive on their own.
- **NAS guest user (`movies`)** is mentioned in setup notes but its password
  is read from a local file at deploy time, never committed.

## Reading list (for the "learning" goal)

- systemd: unit types (service, timer, mount, automount, slice, target),
  user vs system mode, `systemctl --user`, `journalctl -u`, `loginctl enable-linger`
- Podman quadlet: how `.container` files generate `.service` units
- SELinux booleans: `getsebool`, `setsebool -P`, `httpd_can_network_connect`
- firewalld: zones, services vs ports, `--permanent` vs runtime, `--reload`
- NetworkManager: `nmcli` vs the old `ifconfig`/`ifup` world
- Quadlet docs: `man quadlet` and the upstream reference
