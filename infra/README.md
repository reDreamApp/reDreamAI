# Production deployment (Scaleway)

This stack runs on a single Scaleway compute instance alongside a self-hosted Supabase install. The compose file here does **not** include Postgres — Supabase owns it (ADR 0001).

## Topology

```
Scaleway compute instance (Ubuntu LTS)
├── Self-hosted Supabase compose (postgres, kong, auth, storage, …) — network: supabase
└── reDreamAI compose (this file)         — network: default + attaches to supabase
    ├── caddy        TLS via Let's Encrypt, public on 80 / 443
    ├── api          apps/api — backend, connects to supabase-db
    ├── ai           apps/ai — stateless AI service
    └── langfuse     self-hosted v2 (ADR 0007)
```

`caddy` is the only service binding to host ports. Everything else is internal to the docker network.

## First-time setup

1. **Provision the instance (by hand — this IS the runbook).** Terraform's
   scope was deliberately narrowed to the backup bucket only (ADR 0012,
   2026-07-02 amendment); the box is console-provisioned to this exact spec:
   - **Instance**: GP1-S (4 vCPU / 8 GB RAM), image **Ubuntu 24.04 (Noble
     Numbat)**, zone `fr-par-1`, root volume **50 GB** with
     *delete-on-termination OFF* (the volume must survive an instance
     termination).
   - **Public IP**: attach a reserved (not ephemeral) IPv4 — DNS points here.
   - **Security group**: inbound default *drop*, outbound *accept*. Allow
     inbound **22/tcp** (optionally restrict to your IP/VPN range), **80/tcp**,
     **443/tcp**, and **443/udp** (HTTP/3 — Caddy binds QUIC too).
   - **Cloud-init**: paste `infra/cloud-init.yaml` into the user-data field —
     it installs Docker on first boot.
   - Login: `root` via your account's registered SSH key (Scaleway marketplace
     image default).

2. ~~Install Docker~~ — done by step 1's cloud-init user-data.

3. **Install self-hosted Supabase** into `/srv/supabase`. Follow [the official guide](https://supabase.com/docs/guides/self-hosting/docker). Bring it up:
   ```bash
   cd /srv/supabase
   docker compose up -d
   ```
   Confirm the docker network name (default: `supabase_default`). If it differs from `supabase`, adjust the `networks.supabase.external` block in `infra/docker-compose.yml`.

4. **Create the Langfuse database** inside the Supabase Postgres:
   ```bash
   docker compose -f /srv/supabase/docker-compose.yml exec db psql -U postgres -c \
     "CREATE DATABASE langfuse; \
      CREATE USER langfuse WITH PASSWORD '<strong-password>'; \
      GRANT ALL ON DATABASE langfuse TO langfuse;"
   ```

5. **Clone reDreamAI** to `/srv/redreamai`:
   ```bash
   git clone <repo-url> /srv/redreamai
   ```

6. **Fill in env files.** The compose stack reads from `/srv/redreamai/infra/env/`:
   ```bash
   cd /srv/redreamai
   cp infra/env.example/caddy.env.example   infra/env/caddy.env
   cp infra/env.example/ai.env.example      infra/env/ai.env
   cp infra/env.example/api.env.example     infra/env/api.env
   cp infra/env.example/langfuse.env.example infra/env/langfuse.env
   # edit each to fill in real values; never commit them
   ```

7. **DNS.** Point three A records at the instance:
   - `redream.example.com`        (api)
   - `ai.redream.example.com`     (ai — keep DNS private or IP-restrict in Caddyfile)
   - `langfuse.redream.example.com` (langfuse)

8. **Bring the stack up:**
   ```bash
   cd /srv/redreamai/infra
   docker compose up -d --build
   ```
   Caddy will provision TLS certificates on first request.

## Apply DB migrations

Migrations live in `supabase/migrations/`. From your laptop pointed at the production DB:

```bash
supabase db push --db-url "postgresql://postgres:<password>@<scaleway-host>:5432/postgres"
```

Or via the Supabase CLI installed on the box.

## Deploy a new version

Manual, via GitHub Actions:

1. GitHub UI → Actions → **Deploy to Scaleway** → Run workflow.
2. The workflow rsyncs a clean checkout to `/srv/redreamai/` and re-runs `docker compose up -d --build` on the box.

There is **no auto-deploy on `main`** (ADR conventions). Once a `production` branch is in use, the workflow can be wired to trigger on push there.

### Required GitHub secrets

| Secret | What it is |
|---|---|
| `SCALEWAY_HOST`     | Public IP or hostname of the Scaleway instance |
| `SCALEWAY_PORT`     | SSH port (usually `22`) |
| `SCALEWAY_USER`     | SSH user (`root` or your sudo user) |
| `SCALEWAY_SSH_KEY`  | Private SSH key for that user (Ed25519 recommended) |

## Observability

- **Caddy access logs**: `docker compose logs caddy`
- **API + AI structured logs**: `docker compose logs -f api ai`
- **Langfuse traces**: `https://langfuse.redream.example.com`
- **Postgres**: managed via Supabase Studio at the Supabase domain

## Backups

The Supabase Postgres is the single backup target (one Postgres, ADR 0001).

The destination bucket and retention policy are provisioned by `infra/terraform/` (ADR 0012, bucket-only scope) — `nightly/` (7-day), `weekly/` (4-week), `monthly/` (12-month) prefixes with matching lifecycle expiration, output as `backup_bucket_name`.

The `pg_dump` job that uploads into those prefixes lives in `infra/backup/`
(script + systemd timer + install and **restore runbook**). Install it per
`infra/backup/README.md` — and rehearse the restore once.

Caddy data volumes (`caddy_data`, `caddy_config`) hold the TLS certs — back these up too unless you're happy re-issuing on rebuild.

## Tearing down (dev / staging)

```bash
cd /srv/redreamai/infra
docker compose down
# DOES NOT touch Supabase or the Postgres data — only this stack.
```

To wipe Caddy certs (forces re-issuance):
```bash
docker compose down -v   # WARNING: destroys caddy_data + caddy_config volumes
```
