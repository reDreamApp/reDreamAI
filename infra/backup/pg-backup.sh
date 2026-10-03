#!/usr/bin/env bash
# Postgres backup → Scaleway Object Storage (S3-compatible).
#
# Uploads a custom-format pg_dump (pg_restore-able, compressed) plus a
# cluster-roles dump under the bucket prefixes whose RETENTION the bucket's
# lifecycle rules own (infra/terraform/storage.tf):
#   nightly/  kept 7 days   — every run
#   weekly/   kept 28 days  — additionally on Sundays (UTC)
#   monthly/  kept 365 days — additionally on the 1st (UTC)
#
# Config comes from a host-only env file (never in git/rsync — infra/env/ is
# excluded): see infra/backup/README.md for the expected variables.
set -euo pipefail

ENV_FILE="${ENV_FILE:-/srv/redreamai/infra/env/backup.env}"
# Exported, so the aws CLI sees the credentials.
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a
: "${BACKUP_BUCKET:?missing from backup.env}"
: "${AWS_ACCESS_KEY_ID:?missing from backup.env}"
: "${AWS_SECRET_ACCESS_KEY:?missing from backup.env}"
S3_ENDPOINT="${S3_ENDPOINT:-https://s3.fr-par.scw.cloud}"
DB_CONTAINER="${DB_CONTAINER:-supabase-db}"
PGUSER="${PGUSER:-postgres}"
PGDATABASE="${PGDATABASE:-postgres}"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# Single-database dump covers public.* (app), auth.* and storage.* schemas.
docker exec "$DB_CONTAINER" pg_dump -U "$PGUSER" -d "$PGDATABASE" -Fc \
  > "$workdir/db_${stamp}.dump"
# Roles are cluster-level and NOT in pg_dump — needed for a from-scratch
# restore (supabase_admin, authenticator, anon, service_role, ...).
docker exec "$DB_CONTAINER" pg_dumpall -U "$PGUSER" --roles-only \
  > "$workdir/roles_${stamp}.sql"

upload() { # upload <file> <prefix>
  aws s3 cp --only-show-errors --endpoint-url "$S3_ENDPOINT" \
    "$1" "s3://${BACKUP_BUCKET}/$2/"
}

upload "$workdir/db_${stamp}.dump" nightly
upload "$workdir/roles_${stamp}.sql" nightly
if [ "$(date -u +%u)" = "7" ]; then
  upload "$workdir/db_${stamp}.dump" weekly
  upload "$workdir/roles_${stamp}.sql" weekly
fi
if [ "$(date -u +%d)" = "01" ]; then
  upload "$workdir/db_${stamp}.dump" monthly
  upload "$workdir/roles_${stamp}.sql" monthly
fi

echo "backup ${stamp} uploaded to s3://${BACKUP_BUCKET}"
