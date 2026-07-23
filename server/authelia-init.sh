#!/usr/bin/env bash
# Run once on mac-media after deploying quadlet files and starting postgres.
# Prerequisites: postgres container running, ~/srv/authelia/configuration.yml deployed.
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

podman ps --format '{{.Names}}' | grep -q '^postgres$' \
  || die "postgres container not running — start it first: systemctl --user start postgres"

until podman exec postgres pg_isready -U postgres &>/dev/null; do
  echo "  waiting for postgres..."; sleep 2
done

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

for client in jellyfin immich; do
  placeholder="REPLACE_WITH_HASHED_$(echo "$client" | tr '[:lower:]' '[:upper:]')_SECRET"
  if grep -q "$placeholder" "$CONFIG" 2>/dev/null; then
    plaintext=$(openssl rand -hex 32)
    echo "  $client plaintext (save to 1Password): $plaintext"
    hash=$(hash_pbkdf2 "$plaintext")
    sed -i "s|\"$placeholder\"|\"$hash\"|" "$CONFIG"
    echo "  $client: patched into configuration.yml"
  else
    echo "  $client: already configured"
  fi
done

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

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo "==> Init complete. Start remaining services:"
echo "    systemctl --user start valkey authelia"
