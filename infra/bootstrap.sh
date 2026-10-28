#!/usr/bin/env bash
# Set up a fresh box: self-hosted Supabase, env files, migrations, the
# reDreamAI stack, the backup timer and the trace-retention timer. Run as root
# ON THE BOX, with the repo already at /srv/redreamai (infra/README.md,
# "First deploy").
#
# Safe to run again: secrets that exist are kept, everything else is brought
# back in line. Generated secrets are written to files and never printed.
#
# Inputs, from the environment or /srv/redreamai/infra/env/bootstrap.env:
#   DOMAIN             public hostname; supabase.$DOMAIN and langfuse.$DOMAIN
#                      must resolve to this box too
#   SCALEWAY_API_KEY   runtime key secret (tofu output -raw runtime_secret_key)
#   SCALEWAY_PROJECT_ID  project that key is restricted to (tofu output -raw
#                      project_id); may stay empty for a key of the default project
#   MISTRAL_API_KEY    Mistral La Plateforme key (fallback models, TTS)
# Optional:
#   BACKUP_ACCESS_KEY  access key of the runtime key; set it together with
#   BACKUP_BUCKET      the bucket name to enable the nightly Postgres backup
#   S3_ENDPOINT        default https://s3.fr-par.scw.cloud
#   ADMIN_EMAIL        login of the Langfuse admin (default admin@$DOMAIN)
#   LANGFUSE_RETENTION_DAYS  days Langfuse traces are kept (default 30)
set -euo pipefail

REPO=/srv/redreamai
SUPA=/srv/supabase
ENV_DIR=$REPO/infra/env
EXAMPLES=$REPO/infra/env.example

# Pinned versions: the ones this script was last run against.
SUPABASE_REF=${SUPABASE_REF:-self-hosted/v0.8.2}
SUPABASE_CLI_VERSION=${SUPABASE_CLI_VERSION:-2.109.0} # same as CI's migrations job

log() { printf '\n==> %s\n' "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[ "$(id -u)" = 0 ] || die "run as root"
[ -d "$REPO/infra" ] || die "$REPO is missing: copy the repo there first (infra/README.md)"
mkdir -p "$ENV_DIR"
chmod 700 "$ENV_DIR" # every secret of this stack lives in here

if [ -f "$ENV_DIR/bootstrap.env" ]; then
  # shellcheck disable=SC1091
  . "$ENV_DIR/bootstrap.env"
fi
: "${DOMAIN:?set DOMAIN}"
: "${SCALEWAY_API_KEY:?set SCALEWAY_API_KEY}"
: "${MISTRAL_API_KEY:?set MISTRAL_API_KEY}"
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@$DOMAIN}

# set_env <file> <KEY> <value>: replace the KEY= line, or append it.
set_env() {
  if grep -q "^$2=" "$1"; then
    sed -i "s|^$2=.*|$2=$3|" "$1"
  else
    printf '%s=%s\n' "$2" "$3" >>"$1"
  fi
}
get_env() { grep "^$2=" "$1" | head -n1 | cut -d= -f2-; }
secret() { openssl rand -hex 24; }

# ---------------------------------------------------------------- tools ----
if ! command -v supabase >/dev/null; then
  log "Installing the Supabase CLI $SUPABASE_CLI_VERSION"
  curl -fsSL -o /tmp/supabase.deb \
    "https://github.com/supabase/cli/releases/download/v${SUPABASE_CLI_VERSION}/supabase_${SUPABASE_CLI_VERSION}_linux_amd64.deb"
  dpkg -i /tmp/supabase.deb >/dev/null
  rm -f /tmp/supabase.deb
fi

# ------------------------------------------------------------- supabase ----
if [ ! -f "$SUPA/.env" ]; then
  log "Installing self-hosted Supabase ($SUPABASE_REF)"
  curl -fsSL -o /tmp/supabase-setup.sh \
    "https://raw.githubusercontent.com/supabase/supabase/${SUPABASE_REF}/docker/setup.sh"
  # Supabase's own installer: copies its compose files, generates every
  # secret and the ES256 signing key, pulls the images, installs the AWS CLI.
  # It prints the secrets it generates, hence the redirect.
  (cd /srv && sh /tmp/supabase-setup.sh -y --with-aws --project-dir supabase --ref "$SUPABASE_REF" >/dev/null)
  rm -f /tmp/supabase-setup.sh
  # No SMTP is configured, so nobody could confirm an address by mail.
  set_env "$SUPA/.env" ENABLE_EMAIL_AUTOCONFIRM true
fi

log "Configuring Supabase for $DOMAIN"
set_env "$SUPA/.env" SUPABASE_PUBLIC_URL "https://supabase.$DOMAIN"
set_env "$SUPA/.env" API_EXTERNAL_URL "https://supabase.$DOMAIN/auth/v1"
set_env "$SUPA/.env" SITE_URL "https://$DOMAIN"
cp "$REPO/infra/supabase/docker-compose.redream.yml" "$SUPA/"
(cd "$SUPA" && sh run.sh config add redream >/dev/null)

log "Starting Supabase"
(cd "$SUPA" && sh run.sh start)

PG_PASSWORD=$(get_env "$SUPA/.env" POSTGRES_PASSWORD)
ANON_KEY=$(get_env "$SUPA/.env" ANON_KEY)
SERVICE_ROLE_KEY=$(get_env "$SUPA/.env" SERVICE_ROLE_KEY)

# ------------------------------------------------------------ env files ----
log "Writing env files in $ENV_DIR"

# langfuse.env first: the database password and API keys are generated here.
if [ ! -f "$ENV_DIR/langfuse.env" ]; then
  cp "$EXAMPLES/langfuse.env.example" "$ENV_DIR/langfuse.env"
  set_env "$ENV_DIR/langfuse.env" DATABASE_URL "postgresql://langfuse:$(secret)@supabase-db:5432/langfuse"
  set_env "$ENV_DIR/langfuse.env" NEXTAUTH_SECRET "$(secret)"
  set_env "$ENV_DIR/langfuse.env" SALT "$(secret)"
  # Langfuse creates this organisation, project, API key pair and admin user
  # on first start, so sign-up never has to be open.
  set_env "$ENV_DIR/langfuse.env" LANGFUSE_INIT_ORG_ID redreamai
  set_env "$ENV_DIR/langfuse.env" LANGFUSE_INIT_ORG_NAME reDreamAI
  set_env "$ENV_DIR/langfuse.env" LANGFUSE_INIT_PROJECT_ID redreamai
  set_env "$ENV_DIR/langfuse.env" LANGFUSE_INIT_PROJECT_NAME reDreamAI
  set_env "$ENV_DIR/langfuse.env" LANGFUSE_INIT_PROJECT_PUBLIC_KEY "pk-lf-$(secret)"
  set_env "$ENV_DIR/langfuse.env" LANGFUSE_INIT_PROJECT_SECRET_KEY "sk-lf-$(secret)"
  set_env "$ENV_DIR/langfuse.env" LANGFUSE_INIT_USER_EMAIL "$ADMIN_EMAIL"
  set_env "$ENV_DIR/langfuse.env" LANGFUSE_INIT_USER_NAME admin
  set_env "$ENV_DIR/langfuse.env" LANGFUSE_INIT_USER_PASSWORD "$(secret)"
fi
set_env "$ENV_DIR/langfuse.env" NEXTAUTH_URL "https://langfuse.$DOMAIN"
set_env "$ENV_DIR/langfuse.env" AUTH_DISABLE_SIGNUP true
LANGFUSE_DB_PASSWORD=$(get_env "$ENV_DIR/langfuse.env" DATABASE_URL | sed -E 's|^[^:]+://[^:]+:([^@]+)@.*|\1|')
LANGFUSE_PUBLIC_KEY=$(get_env "$ENV_DIR/langfuse.env" LANGFUSE_INIT_PROJECT_PUBLIC_KEY)
LANGFUSE_SECRET_KEY=$(get_env "$ENV_DIR/langfuse.env" LANGFUSE_INIT_PROJECT_SECRET_KEY)

printf 'DOMAIN=%s\n' "$DOMAIN" >"$ENV_DIR/caddy.env"

[ -f "$ENV_DIR/ai.env" ] || cp "$EXAMPLES/ai.env.example" "$ENV_DIR/ai.env"
set_env "$ENV_DIR/ai.env" SCALEWAY_API_KEY "$SCALEWAY_API_KEY"
set_env "$ENV_DIR/ai.env" SCALEWAY_PROJECT_ID "${SCALEWAY_PROJECT_ID:-}"
set_env "$ENV_DIR/ai.env" MISTRAL_API_KEY "$MISTRAL_API_KEY"
set_env "$ENV_DIR/ai.env" SUPABASE_SERVICE_ROLE_KEY "$SERVICE_ROLE_KEY"
set_env "$ENV_DIR/ai.env" SUPABASE_PUBLIC_URL "https://supabase.$DOMAIN"
set_env "$ENV_DIR/ai.env" LANGFUSE_PUBLIC_KEY "$LANGFUSE_PUBLIC_KEY"
set_env "$ENV_DIR/ai.env" LANGFUSE_SECRET_KEY "$LANGFUSE_SECRET_KEY"

if [ ! -f "$ENV_DIR/api.env" ]; then
  cp "$EXAMPLES/api.env.example" "$ENV_DIR/api.env"
  set_env "$ENV_DIR/api.env" REPORT_INTERNAL_ACTION_KEY "$(secret)"
  set_env "$ENV_DIR/api.env" REPORT_NOTIFICATION_HMAC_SECRET "$(secret)"
fi
set_env "$ENV_DIR/api.env" DATABASE_URL "postgresql+asyncpg://postgres:$PG_PASSWORD@supabase-db:5432/postgres"
set_env "$ENV_DIR/api.env" SUPABASE_ANON_KEY "$ANON_KEY"
set_env "$ENV_DIR/api.env" SUPABASE_SERVICE_ROLE_KEY "$SERVICE_ROLE_KEY"
# The issuer GoTrue puts into tokens is exactly its API_EXTERNAL_URL.
set_env "$ENV_DIR/api.env" SUPABASE_JWT_ISS "https://supabase.$DOMAIN/auth/v1"
set_env "$ENV_DIR/api.env" REPORT_ACTION_BASE_URL "https://$DOMAIN/internal"
# For the GDPR purge: the backend deletes a user's traces in Langfuse's database.
set_env "$ENV_DIR/api.env" LANGFUSE_DATABASE_URL "postgresql+asyncpg://langfuse:$LANGFUSE_DB_PASSWORD@supabase-db:5432/langfuse"

# Migrations go to Postgres directly, on the loopback port from
# infra/supabase/docker-compose.redream.yml.
SUPABASE_DB_URL="postgresql://postgres:$PG_PASSWORD@127.0.0.1:54322/postgres?sslmode=disable"
printf 'SUPABASE_DB_URL=%s\n' "$SUPABASE_DB_URL" >"$ENV_DIR/deploy.env"

if [ -n "${BACKUP_BUCKET:-}" ] && [ -n "${BACKUP_ACCESS_KEY:-}" ]; then
  {
    printf 'AWS_ACCESS_KEY_ID=%s\n' "$BACKUP_ACCESS_KEY"
    printf 'AWS_SECRET_ACCESS_KEY=%s\n' "${BACKUP_SECRET_KEY:-$SCALEWAY_API_KEY}"
    printf 'BACKUP_BUCKET=%s\n' "$BACKUP_BUCKET"
    printf 'S3_ENDPOINT=%s\n' "${S3_ENDPOINT:-https://s3.fr-par.scw.cloud}"
  } >"$ENV_DIR/backup.env"
fi
if [ -n "${LANGFUSE_RETENTION_DAYS:-}" ]; then
  printf 'LANGFUSE_RETENTION_DAYS=%s\n' "$LANGFUSE_RETENTION_DAYS" >"$ENV_DIR/retention.env"
fi
chmod 600 "$ENV_DIR"/*.env

# ------------------------------------------------------------- database ----
log "Langfuse database"
psql_db() { docker exec supabase-db psql -U postgres -v ON_ERROR_STOP=1 -qtA "$@"; }
if [ "$(psql_db -c "select count(*) from pg_roles where rolname = 'langfuse'")" = 0 ]; then
  psql_db -c "create role langfuse login password '$LANGFUSE_DB_PASSWORD'"
fi
if [ "$(psql_db -c "select count(*) from pg_database where datname = 'langfuse'")" = 0 ]; then
  # `postgres` is not a superuser in the Supabase image: it may only hand a
  # database to a role it is a member of.
  psql_db -c "grant langfuse to postgres"
  psql_db -c "create database langfuse owner langfuse"
fi

log "Applying migrations"
(cd "$REPO" && supabase db push --db-url "$SUPABASE_DB_URL" --include-all --yes)

# ---------------------------------------------------------------- stack ----
log "Building and starting the reDreamAI stack"
mkdir -p /srv/downloads
(cd "$REPO/infra" && docker compose up -d --build)

# --------------------------------------------------------------- backup ----
if [ -f "$ENV_DIR/backup.env" ]; then
  log "Enabling the nightly Postgres backup"
  chmod +x "$REPO/infra/backup/pg-backup.sh"
  ln -sf "$REPO/infra/backup/pg-backup.service" /etc/systemd/system/
  ln -sf "$REPO/infra/backup/pg-backup.timer" /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable --now pg-backup.timer
fi

# ------------------------------------------------------------ retention ----
log "Enabling the daily Langfuse trace retention"
ln -sf "$REPO/infra/langfuse/langfuse-retention.service" /etc/systemd/system/
ln -sf "$REPO/infra/langfuse/langfuse-retention.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now langfuse-retention.timer

cat <<EOF

Done.
  API        https://$DOMAIN/api/v1/health
  Supabase   https://supabase.$DOMAIN   (auth and signed audio URLs only)
  Langfuse   https://langfuse.$DOMAIN   (off by default, see infra/.env.example;
             login: $ADMIN_EMAIL, password: LANGFUSE_INIT_USER_PASSWORD
             in $ENV_DIR/langfuse.env)

For the app's .env:
  SUPABASE_URL=https://supabase.$DOMAIN
  API_BASE_URL=https://$DOMAIN
  SUPABASE_ANON_KEY=  -> ANON_KEY in $SUPA/.env
EOF
