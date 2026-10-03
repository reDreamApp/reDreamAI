#!/usr/bin/env bash
# Langfuse trace retention: delete traces, observations and scores older than
# LANGFUSE_RETENTION_DAYS (default 30), and the chat sessions left empty.
#
# Langfuse v2 has no retention setting (ADR 0007), so this runs SQL in its
# database once a day, from langfuse-retention.timer. Traces hold the full
# conversation text; this job is what bounds how long that text is kept.
#
# To keep traces for another period, write a host-only file (infra/env/ is
# never in git or rsync):
#   echo LANGFUSE_RETENTION_DAYS=60 > /srv/redreamai/infra/env/retention.env
set -euo pipefail

ENV_FILE="${ENV_FILE:-/srv/redreamai/infra/env/retention.env}"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi
DAYS="${LANGFUSE_RETENTION_DAYS:-30}"
DB_CONTAINER="${DB_CONTAINER:-supabase-db}"

case "$DAYS" in
  '' | *[!0-9]* | 0)
    echo "LANGFUSE_RETENTION_DAYS must be a whole number of days above 0 (got '$DAYS')" >&2
    exit 1
    ;;
esac

# Age is counted from created_at, the time Langfuse stored the row (UTC).
# psql prints one "DELETE <n>" per statement into the journal.
docker exec -i "$DB_CONTAINER" psql -U postgres -d langfuse -v ON_ERROR_STOP=1 -v days="$DAYS" <<'SQL'
BEGIN;
SELECT (now() AT TIME ZONE 'utc') - make_interval(days => :days) AS cutoff \gset
DELETE FROM scores WHERE created_at < :'cutoff';
DELETE FROM observations WHERE created_at < :'cutoff';
DELETE FROM traces WHERE created_at < :'cutoff';
DELETE FROM trace_sessions WHERE created_at < :'cutoff'
  AND NOT EXISTS (SELECT 1 FROM traces WHERE traces.session_id = trace_sessions.id);
COMMIT;
SQL

echo "langfuse retention: rows older than ${DAYS} days removed"
