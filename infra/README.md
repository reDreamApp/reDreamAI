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

1. **Provision the instance.** Recommended: Scaleway GP1-S (4 vCPU / 8 GB RAM, Ubuntu 24.04 LTS, Paris). Configure SSH, firewall to allow 22 / 80 / 443.

2. **Install Docker.**
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   ```

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

Recommended setup (not yet automated):
- Nightly `pg_dump` to Scaleway Object Storage with 7-day retention.
- Weekly snapshot retained 4 weeks.
- Monthly snapshot retained 12 months.

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
