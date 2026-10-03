FROM python:3.12-slim-bookworm AS base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.5 /uv /usr/local/bin/uv

WORKDIR /app

COPY pyproject.toml uv.lock* ./
RUN uv sync --frozen --no-install-project --no-dev 2>/dev/null \
    || uv sync --no-install-project --no-dev

COPY src ./src
RUN uv sync --frozen --no-dev 2>/dev/null || uv sync --no-dev

RUN useradd --no-create-home --uid 10001 appuser
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8080/health || exit 1

# Run uvicorn from the synced venv directly: `uv run` at runtime needs a
# writable $HOME cache, which the no-home appuser doesn't have.
CMD ["/app/.venv/bin/uvicorn", "redream_ai.main:app", "--host", "0.0.0.0", "--port", "8080"]
