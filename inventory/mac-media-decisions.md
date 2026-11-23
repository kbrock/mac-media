# mac-media Decisions

## Firewall: only nginx, ssh, cockpit, mdns, and Govee discovery are opened

- **80/443/tcp** — nginx, the only path in for every service (jellyfin,
  navidrome, homeassistant proxy through it via `127.0.0.1`, no direct
  LAN port needed for them).
- **ssh, cockpit** — admin access.
- **mdns service (5353/udp)** — Home Assistant's own zeroconf/discovery,
  not a system Avahi daemon (none installed).
- **4001-4003/udp** — Govee LAN light discovery. UDP broadcast, can't be
  proxied through nginx, so opened directly.

## Authelia removed from nginx for movies.home.thebrocks.net

Chose: dropped `auth_request` from Jellyfin's `location /` entirely.
Jellyfin's own login page is the gate — browsers use the SSO-Auth plugin
(redirects to Authelia OIDC), native apps (Moonfin, etc.) use Quick
Connect or a Jellyfin token. Unlike HA, Jellyfin has no
`trusted_networks`-style unauthenticated fallback, so there's no
anonymous path opened up by removing nginx's layer.

Why: nginx's `auth_request` was blocking native-app API calls
(`/System`, `/Sessions`, `/socket`, `/Users/Me`, etc.) with 401s after
Quick Connect login succeeded, since those calls carry a Jellyfin token,
not an Authelia session cookie. Bypassing path-by-path wasn't
sustainable as the app's API surface grew; removing the redundant
nginx-level gate (Jellyfin's login already requires Authelia SSO or an
approved Quick Connect code) fixed it at the source.
