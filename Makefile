REMOTE := mac-media

.PHONY: all setup creds landing quadlets nginx diff

all: landing quadlets nginx

setup:
	rsync -av --exclude='*.env' server/ $(REMOTE):server/

creds:
	scp -p server/certbot/cloudflare.ini $(REMOTE):server/certbot/cloudflare.ini

landing:
	rsync -av --delete server/landing/ $(REMOTE):srv/landing/

quadlets:
	rsync -av server/quadlet/ $(REMOTE):.config/containers/systemd/
	ssh $(REMOTE) 'systemctl --user daemon-reload'
	@echo
	@echo "Restart changed services manually, e.g.:"
	@echo "  ssh $(REMOTE) 'systemctl --user restart jellyfin'"

nginx:
	rsync -av --delete server/nginx/ $(REMOTE):nginx-staging/
	ssh -t $(REMOTE) 'sudo cp -r ~/nginx-staging/. /etc/nginx/ && \
	               sudo nginx -t && sudo systemctl reload nginx'

diff:
	@echo "=== landing ==="
	-rsync -avn --delete server/landing/ $(REMOTE):srv/landing/
	@echo "=== quadlets ==="
	-rsync -avn server/quadlet/ $(REMOTE):.config/containers/systemd/
	@echo "=== nginx ==="
	-rsync -avn --delete server/nginx/ $(REMOTE):nginx-staging/
