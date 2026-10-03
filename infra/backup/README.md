# Postgres backups

Nightly `pg_dump` of the self-hosted Supabase Postgres, uploaded to the
Scaleway Object Storage bucket from `infra/terraform/storage.tf`. **Retention
is owned by the bucket's lifecycle rules** (nightly 7 d / weekly 28 d /
monthly 365 d) — the job only uploads to the matching prefix.

Each run produces two objects:

- `db_<stamp>.dump` — custom-format `pg_dump` of the `postgres` database
  (covers `public.*` app schema, `auth.*`, `storage.*`). Restore with
  `pg_restore`.
- `roles_<stamp>.sql` — cluster roles (`pg_dumpall --roles-only`). Only needed
  for a from-scratch restore (roles are not part of `pg_dump`).

## Install

`infra/bootstrap.sh` does it when `BACKUP_BUCKET` and `BACKUP_ACCESS_KEY` are
set: it installs the AWS CLI (through Supabase's installer), writes the
host-only `/srv/redreamai/infra/env/backup.env` and enables the timer.

```bash
# backup.env — values are outputs of infra/terraform
AWS_ACCESS_KEY_ID=<runtime_access_key>
AWS_SECRET_ACCESS_KEY=<runtime_secret_key>
BACKUP_BUCKET=<backup_bucket_name>
S3_ENDPOINT=https://s3.fr-par.scw.cloud
# Optional overrides (defaults shown):
# DB_CONTAINER=supabase-db
# PGUSER=postgres
# PGDATABASE=postgres
```

```bash
systemctl list-timers pg-backup.timer         # next run
systemctl start pg-backup.service             # run one backup right now
journalctl -u pg-backup.service -n 20         # what it did
```

The runtime key may upload, list and download, but not delete: expiry is the
bucket's lifecycle rules.

## Restore

> A backup nobody has restored from is a hope, not a backup. Rehearse this
> once now, and after any Postgres major upgrade. Record rehearsals below.

### Sanity restore (rehearsal — into a scratch DB, prod untouched)

```bash
# 1. Fetch the newest dump
aws s3 cp "s3://<bucket>/nightly/<db_...>.dump" /tmp/restore.dump \
  --endpoint-url https://s3.fr-par.scw.cloud

# 2. Restore into a scratch database inside the running container
docker exec supabase-db createdb -U postgres restore_check
docker cp /tmp/restore.dump supabase-db:/tmp/restore.dump
docker exec supabase-db pg_restore -U postgres -d restore_check \
  --no-owner --no-privileges /tmp/restore.dump

# 3. Sanity checks — counts should match prod within a day's drift
docker exec supabase-db psql -U postgres -d restore_check -c \
  "SELECT (SELECT count(*) FROM public.chats)    AS chats,
          (SELECT count(*) FROM public.chat_messages) AS messages,
          (SELECT count(*) FROM public.dreams)   AS dreams,
          (SELECT count(*) FROM auth.users)      AS users;"

# 4. Clean up
docker exec supabase-db dropdb -U postgres restore_check
docker exec supabase-db rm /tmp/restore.dump
```

### Full disaster recovery (new box)

1. Bring up the self-hosted Supabase stack (empty Postgres).
2. Apply roles FIRST: `psql -U postgres -f roles_<stamp>.sql` (ignore
   "role already exists" errors for the built-ins the stack pre-creates).
3. `pg_restore -U postgres -d postgres --clean --if-exists db_<stamp>.dump`.
4. Re-run the sanity-check query above against `postgres`.
5. Start api/ai containers; verify `/health` and one authenticated request.

## Rehearsal log

| Date | Dump used | Result | Notes |
|---|---|---|---|
| 2026-10-03 | `db_20261003T184217Z.dump` | OK: row counts identical to live (app users, chats, messages, consents, auth users) | Fresh box, test data only. `pg_restore` exits 1 with two expected errors as `postgres` (not a superuser): `set parameter "log_min_messages"` and `table secrets` (Supabase Vault). Neither touches app data. |
