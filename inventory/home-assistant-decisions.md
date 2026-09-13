# Home Assistant Decisions

## trusted_networks auto-login as admin for all users

Chose: `trusted_networks` auth provider auto-logs in as `kbrock` (admin)
for any request arriving via nginx from `127.0.0.1`. `homeassistant`
provider kept as fallback for direct access (bypassing nginx).

Why: identity is handled at the Authelia layer (nginx forward auth) before
the request reaches HA; HA itself doesn't need per-user accounts to know
who's asking. One shared admin session is simpler than replicating
Authelia's four users inside HA too. Added as part of the Authelia SSO
rollout (`TODO.md` Phase 2).

## VW Group Connect (vag_connect) skipped for now

HACS custom repo `its-me-prash/vwgroup-connect-ha` only supports EU Brand
ID accounts (VW EU, Audi, Škoda, SEAT/CUPRA, Porsche). US Volkswagen uses
a separate Car-Net backend this integration doesn't support. Installed via
HACS but left unconfigured — check for a US-compatible alternative before
proceeding.
