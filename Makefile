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
	rsync -av server/nginx/ $(REMOTE):nginx-staging/
	ssh -t $(REMOTE) 'sudo cp ~/nginx-staging/nginx.conf /etc/nginx/nginx.conf && \
	               sudo cp ~/nginx-staging/home.conf /etc/nginx/conf.d/home.conf && \
	               sudo rm -f /etc/nginx/conf.d/mac-media.conf && \
	               sudo nginx -t && sudo systemctl reload nginx'

diff:
	@echo "=== landing ==="
	-rsync -avn --delete server/landing/ $(REMOTE):srv/landing/
	@echo "=== quadlets ==="
	-rsync -avn server/quadlet/ $(REMOTE):.config/containers/systemd/
	@echo "=== nginx ==="
	-rsync -avn server/nginx/ $(REMOTE):nginx-staging/
