REMOTE := mac-media
QUADLET_SERVICES := authelia jellyfin navidrome homeassistant postgres valkey
GROCERIES_SRC ?= ../groceries

.PHONY: all setup creds landing groceries-seed quadlets nginx nas-mounts revive diff $(QUADLET_SERVICES)

all: landing quadlets nginx

setup:
	rsync -av --exclude='*.env' server/ $(REMOTE):server/

creds:
	scp -p server/certbot/cloudflare.ini $(REMOTE):server/certbot/cloudflare.ini

landing:
	ssh $(REMOTE) 'mkdir -p build/landing'
	rsync -av --delete --exclude-from=$(GROCERIES_SRC)/.containerignore $(GROCERIES_SRC)/ $(REMOTE):build/landing/
	scp server/quadlet/landing.container $(REMOTE):.config/containers/systemd/
	ssh $(REMOTE) 'podman build -t localhost/landing:latest -f build/landing/Containerfile build/landing && \
	  systemctl --user daemon-reload && systemctl --user restart landing'

groceries-seed:
	ssh $(REMOTE) 'mkdir -p srv/groceries'
	rsync -av --ignore-existing server/seed/groceries.md $(REMOTE):srv/groceries/

quadlets:
	rsync -av server/quadlet/ $(REMOTE):.config/containers/systemd/
	ssh $(REMOTE) 'systemctl --user daemon-reload && \
	  for s in $(QUADLET_SERVICES); do systemctl --user restart $$s; done'

nginx:
	rsync -av --delete server/nginx/ $(REMOTE):nginx-staging/
	ssh -t $(REMOTE) 'sudo cp -r ~/nginx-staging/. /etc/nginx/ && \
	               sudo nginx -t && sudo systemctl reload nginx'

nas-mounts:
	rsync -av server/nas-mounts/ $(REMOTE):nas-mounts-staging/
	ssh -t $(REMOTE) 'sudo cp nas-mounts-staging/*.mount nas-mounts-staging/*.automount /etc/systemd/system/ && \
	               sudo systemctl daemon-reload && \
	               sudo systemctl restart mnt-nas-music.mount mnt-nas-video.mount'

# Per-service: scp that service's quadlet (+ any service-specific config it
# has) and restart it. quadlets above is the bulk equivalent — syncs every
# quadlet but leaves restarting to you.
authelia:
	scp server/authelia/configuration.yml $(REMOTE):srv/authelia/configuration.yml
	scp server/quadlet/authelia.container $(REMOTE):.config/containers/systemd/
	ssh $(REMOTE) 'systemctl --user daemon-reload && systemctl --user restart authelia'

$(filter-out authelia,$(QUADLET_SERVICES)):
	scp server/quadlet/$@.container $(REMOTE):.config/containers/systemd/
	ssh $(REMOTE) 'systemctl --user daemon-reload && systemctl --user restart $@'

# Quadlets carry StartLimitIntervalSec/StartLimitBurst — a service that
# crash-loops past that limit goes `failed` and refuses stop/start until
# reset-failed clears it. Finds every failed --user unit and revives it.
revive:
	ssh $(REMOTE) 'for u in $$(systemctl --user list-units --state=failed --no-legend --plain | awk "{print \$$1}"); do \
	  echo "reviving $$u"; systemctl --user reset-failed $$u && systemctl --user restart $$u; done'

diff:
	@echo "=== landing ==="
	-rsync -avn --delete --exclude-from=$(GROCERIES_SRC)/.containerignore $(GROCERIES_SRC)/ $(REMOTE):build/landing/
	@echo "=== quadlets ==="
	-rsync -avn server/quadlet/ $(REMOTE):.config/containers/systemd/
	@echo "=== nginx ==="
	-rsync -avn --delete server/nginx/ $(REMOTE):nginx-staging/
