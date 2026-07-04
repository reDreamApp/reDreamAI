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

## Install (once, on the Scaleway host)

```bash
# 1. aws CLI (any S3 client works; the script uses `aws s3 cp`)
sudo apt-get install -y awscli

# 2. Host-only credentials (never in git/rsync)
sudo tee /srv/redreamai/infra/env/backup.env >/dev/null <<'EOF'
AWS_ACCESS_KEY_ID=<scaleway-access-key>
AWS_SECRET_ACCESS_KEY=<scaleway-secret-key>
BACKUP_BUCKET=<bucket name from terraform>
# Optional overrides (defaults shown):
# S3_ENDPOINT=https://s3.fr-par.scw.cloud
# DB_CONTAINER=supabase-db
# PGUSER=postgres
# PGDATABASE=postgres
EOF
sudo chmod 600 /srv/redreamai/infra/env/backup.env

# 3. Units + timer
chmod +x /srv/redreamai/infra/backup/pg-backup.sh
sudo ln -sf /srv/redreamai/infra/backup/pg-backup.service /etc/systemd/system/
sudo ln -sf /srv/redreamai/infra/backup/pg-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now pg-backup.timer

# 4. Verify
systemctl list-timers pg-backup.timer
sudo systemctl start pg-backup.service        # run one backup right now
aws s3 ls "s3://<bucket>/nightly/" --endpoint-url https://s3.fr-par.scw.cloud
```

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
| _none yet_ | | | first rehearsal pending — do it once the timer has produced a real dump |
