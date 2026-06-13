# Server Projects (backlog)

Not yet committed. Things we might do.

## Authelia (SSO)

Auth portal at `auth.home.thebrocks.net`. Goal: identity, not security.
One login for all services; each app knows who you are for personalization.

Users (username = first-initial + last, password = first name):
- kbrock / keenan (admin)
- vbrock / valerie
- tbrock / toby
- rbrock / reid

Shared infrastructure with Immich: Redis (session store) + Postgres (storage backend).

Per-service decisions:
- **Jellyfin** — nginx forward auth + OIDC (SSO-Auth plugin, already installed)
- **Home Assistant** — nginx forward auth + trusted_networks auto-login as admin for all users
- **Navidrome** — nginx forward auth for browser; `/rest/` bypasses auth, username read from `$arg_u` query param (no password check, LAN-only acceptable). Amperfy uses username only.
- **Immich** — nginx forward auth + OIDC native

## Immich

Self-hosted photo library at `photos.home.thebrocks.net` (port 2283).
Library on NAS. Postgres + Redis shared with Authelia.

## Backup (decision: B2)

~50GB of photos + files + configs. Set up after photo dedup stabilizes.

| Option       | Cost              |
|--------------|-------------------|
| B2 (chosen)  | ~$4/mo            |
| Wasabi       | $5/mo, free egress |
| Synology C2  | ~$60/yr, Synology-locked |
| AWS Glacier  | $1/mo + retrieval |

Actions: sign up B2, configure Hyper Backup on DSM, document recovery.

## Home Assistant dashboard

Custom Sections dashboard, halfway done.

- Add device sections (Wall-E, Govee lights, car charger, Emporia plugs)
- Pick entities per device (skip noise)
- History graph cards for bed temp / sleep metrics

## Home Assistant integrations

- Emporia plugs x4
- Govee H6066 (no LAN; firmware update or skip)
- VocoLinc SmartBar (HomeKit-native, locations unknown)

## Cert distribution from mac-media

Push the LE wildcard cert from mac-media to other LAN devices so their web
UIs use a trusted cert instead of self-signed.

Targets:
- **diskstation.home.thebrocks.net** → Synology DSM 7. Tool: `synowebapi`
  (community) — upload cert via DSM Certificate API, trigger service reload.
- **fortknox.home.thebrocks.net** → UDM. Tool: `ubios-cert` (community)
  — drops cert into the right path, restarts UniFi services.

Simplest fallback: scp cert + key, bounce the relevant service.

## Vault

Quadlet on mac-media. KV store for cloudflare tokens, NAS guest password,
quadlet env vars, rsync passwords, NAS / mac-media ssh keys.

Unseal keys live in 1Password (recovery layer).

Priority: after harness exists.

## Universal media voice search

Voice query (Roku / Alexa / HA) → MCP server → Jellyfin (and ideally Netflix,
Hulu). Existing: `jellyfin-mcp` (github.com/jaredtrent/jellyfin-mcp). Gap:
polished open-source cross-service aggregator.
