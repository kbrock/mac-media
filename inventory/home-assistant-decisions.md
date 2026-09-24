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

## Authelia bypassed for /api and /auth/token on hub.home.thebrocks.net

Chose: nginx bypasses Authelia's `auth_request` for `^/(api|auth/token)` on
`hub.home.thebrocks.net`, proxying straight to HA. HA's own
`trusted_networks` auto-login (see above) is what actually gates these
paths. `/auth/authorize` (the OAuth login page) stays behind Authelia —
that's the intended SSO login step, not something to bypass.

Why: the HA Companion App authenticates directly against the API
(long-lived token / OAuth token exchange), not via a browser session. It
can't follow Authelia's redirect-based login challenge, so leaving
`/auth/token` behind `auth_request` meant the app could never finish
login after the Authelia SSO screen. Safe only
because this deployment has no port-forwarding and no public DNS records
(`network-decisions.md`) — anyone who can reach `hub.home.thebrocks.net`
is already on the LAN. **If port 443 is ever forwarded externally, this
bypass plus `trusted_networks` trusting 127.0.0.1 becomes an
unauthenticated admin login for anyone on the internet — revisit before
exposing this host.**

