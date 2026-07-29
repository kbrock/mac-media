REMOTE := mac-media
QUADLET_SERVICES := authelia jellyfin navidrome homeassistant postgres valkey

.PHONY: all setup creds landing quadlets nginx diff $(QUADLET_SERVICES)

all: landing quadlets nginx

setup:
	rsync -av --exclude='*.env' server/ $(REMOTE):server/

creds:
	scp -p server/certbot/cloudflare.ini $(REMOTE):server/certbot/cloudflare.ini

landing:
	rsync -av --delete server/landing/ $(REMOTE):srv/landing/

quadlets:
	rsync -av server/quadlet/ $(REMOTE):.config/containers/systemd/
	ssh $(REMOTE) 'systemctl --user daemon-reload && \
	  for s in $(QUADLET_SERVICES); do systemctl --user restart $$s; done'

nginx:
	rsync -av --delete server/nginx/ $(REMOTE):nginx-staging/
	ssh -t $(REMOTE) 'sudo cp -r ~/nginx-staging/. /etc/nginx/ && \
	               sudo nginx -t && sudo systemctl reload nginx'

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

diff:
	@echo "=== landing ==="
	-rsync -avn --delete server/landing/ $(REMOTE):srv/landing/
	@echo "=== quadlets ==="
	-rsync -avn server/quadlet/ $(REMOTE):.config/containers/systemd/
	@echo "=== nginx ==="
	-rsync -avn --delete server/nginx/ $(REMOTE):nginx-staging/
