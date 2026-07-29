#!/usr/bin/env bash
# Run once on mac-media after deploying quadlet files.
# Prerequisites: ~/srv/authelia/configuration.yml deployed, data dirs created.
set -euo pipefail

AUTHELIA_DIR="$HOME/srv/authelia"
CONFIG="$AUTHELIA_DIR/configuration.yml"
AUTHELIA_IMAGE="ghcr.io/authelia/authelia:latest"

die()          { echo "ERROR: $*" >&2; exit 1; }
secret_exists(){ podman secret inspect "$1" &>/dev/null; }

load_secret() {
  local name=$1 value=$2
  if secret_exists "$name"; then
    echo "  $name: already exists, skipping"
  else
    echo -n "$value" | podman secret create "$name" - >/dev/null
    echo "  $name: created"
  fi
}

hash_pbkdf2() {
  echo -n "$1" | podman run --rm -i "$AUTHELIA_IMAGE" \
    authelia crypto hash generate pbkdf2 --variant sha512 2>/dev/null | awk '/Digest/{print $2}'
}

hash_argon2() {
  podman run --rm "$AUTHELIA_IMAGE" \
    authelia crypto hash generate argon2 --password "$1" 2>/dev/null | awk '/Digest/{print $2}'
}

# ── Prerequisites ────────────────────────────────────────────────────────────

[ -f "$CONFIG" ] || die "configuration.yml not found at $CONFIG — deploy it first"

# ── 1. Service secrets ───────────────────────────────────────────────────────

echo ""
echo "==> Service secrets"

load_secret authelia_jwt_secret             "$(openssl rand -hex 32)"
load_secret authelia_session_secret         "$(openssl rand -hex 32)"
load_secret authelia_storage_encryption_key "$(openssl rand -hex 32)"
load_secret authelia_oidc_hmac_secret       "$(openssl rand -hex 32)"
load_secret postgres_password               "$(openssl rand -hex 32)"

# Keep in memory — needed for postgres user creation below
if secret_exists authelia_storage_postgres_password; then
  echo "  authelia_storage_postgres_password: already exists, skipping"
  AUTHELIA_PG_PASS=""
else
  AUTHELIA_PG_PASS=$(openssl rand -hex 32)
  echo -n "$AUTHELIA_PG_PASS" | podman secret create authelia_storage_postgres_password - >/dev/null
  echo "  authelia_storage_postgres_password: created"
fi

# ── 2. OIDC signing key ──────────────────────────────────────────────────────

echo ""
echo "==> OIDC signing key"

if [ -f "$AUTHELIA_DIR/oidc.key" ]; then
  echo "  oidc.key: already exists, skipping"
else
  openssl genrsa -out "$AUTHELIA_DIR/oidc.key" 4096 2>/dev/null
  chmod 600 "$AUTHELIA_DIR/oidc.key"
  echo "  oidc.key: generated"
fi

# ── 3. OIDC client secrets ───────────────────────────────────────────────────

echo ""
echo "==> OIDC client secrets"
echo "    Save the plaintext values to 1Password before continuing."
echo ""

secrets_file="$AUTHELIA_DIR/oidc-client-secrets.txt"
[ -f "$secrets_file" ] || touch "$secrets_file" && chmod 600 "$secrets_file"

# configuration.yml references each client's hash via
# {{ secret "/config/<client>-client-secret.hash" | msquote }} — this script
# owns generating that file, nothing to hand-write.
for client in jellyfin immich; do
  hash_file="$AUTHELIA_DIR/$client-client-secret.hash"
  if [ -f "$hash_file" ]; then
    echo "  $client: $hash_file already exists, skipping"
  else
    plaintext=$(openssl rand -hex 32)
    hash=$(hash_pbkdf2 "$plaintext")
    printf '%s' "$hash" > "$hash_file"
    chmod 600 "$hash_file"
    echo "$client: $plaintext" >> "$secrets_file"
    echo "  $client: $hash_file written"
  fi
done

echo "  plaintext secrets saved to $secrets_file (delete after configuring apps)"

# ── 4. User passwords ────────────────────────────────────────────────────────

echo ""
echo "==> User passwords (argon2, ~2s per user)"
echo ""

write_user() {
  local username=$1 displayname=$2 email=${3:-""} groups=${4:-"[]"}
  read -rsp "  Password for $username ($displayname): " password
  echo ""
  local hash
  hash=$(hash_argon2 "$password")
  cat >> "$AUTHELIA_DIR/users_database.yml" <<EOF
  $username:
    displayname: $displayname
    password: "$hash"
    email: "$email"
    groups: $groups
EOF
}

cat > "$AUTHELIA_DIR/users_database.yml" <<'EOF'
---
users:
EOF

write_user kbrock Keenan "keenan@thebrocks.net" "[admins]"
write_user vbrock Valerie
write_user tbrock Toby
write_user rbrock Reid

echo "  users_database.yml written"

# ── 5. Postgres authelia user + database ─────────────────────────────────────

echo ""
echo "==> Postgres database"

if ! podman ps --format '{{.Names}}' | grep -q '^postgres$'; then
  echo "  starting postgres..."
  systemctl --user start postgres
fi

deadline=$(( $(date +%s) + 60 ))
until podman exec postgres pg_isready -U postgres &>/dev/null; do
  (( $(date +%s) < deadline )) || die "postgres did not become ready within 60s"
  echo "  waiting for postgres..."; sleep 2
done

if podman exec postgres psql -U postgres -tc \
    "SELECT 1 FROM pg_roles WHERE rolname='authelia'" | grep -q 1; then
  echo "  authelia user: already exists"
elif [ -z "$AUTHELIA_PG_PASS" ]; then
  echo "  WARNING: authelia_storage_postgres_password secret already existed but"
  echo "  authelia postgres user does not. Create it manually:"
  echo "    podman exec -it postgres psql -U postgres"
  echo "    CREATE USER authelia WITH PASSWORD '<value from podman secret>';"
  echo "    CREATE DATABASE authelia OWNER authelia;"
else
  podman exec -i postgres psql -U postgres <<SQL
CREATE USER authelia WITH PASSWORD '$AUTHELIA_PG_PASS';
CREATE DATABASE authelia OWNER authelia;
SQL
  echo "  authelia user and database: created"
fi

# ── 6. Start remaining services ──────────────────────────────────────────────

echo ""
echo "==> Starting valkey and authelia"
systemctl --user start valkey authelia

# ── 7. Deploy nginx ───────────────────────────────────────────────────────────

echo ""
echo "==> Deploying nginx config"
sudo cp ~/authelia-forward-auth.conf /etc/nginx/
sudo cp ~/home.conf /etc/nginx/conf.d/
sudo nginx -t && sudo systemctl reload nginx
echo "  nginx reloaded"

echo ""
echo "==> Done. Verify at https://auth.home.thebrocks.net"
