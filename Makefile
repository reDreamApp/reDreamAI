.DEFAULT_GOAL := help
SHELL := /bin/bash

# ---- meta ---------------------------------------------------------------

.PHONY: help
help: ## show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ---- ai service ---------------------------------------------------------

.PHONY: ai-dev ai-test ai-lint ai-fmt
ai-dev: ## run AI service locally on :8080
	cd apps/ai && uv run uvicorn redream_ai.main:app --reload --port 8080

ai-test: ## run AI service tests
	cd apps/ai && uv run pytest

ai-lint: ## lint AI service
	cd apps/ai && uv run ruff check . && uv run mypy src

ai-fmt: ## format AI service
	cd apps/ai && uv run ruff format . && uv run ruff check --fix .

# ---- api (backend) ------------------------------------------------------

.PHONY: api-dev api-test api-lint api-fmt
api-dev: ## run backend locally on :8001
	cd apps/api && uv run uvicorn redream_api.main:app --reload --port 8001

api-test: ## run backend tests
	cd apps/api && uv run pytest

api-lint: ## lint backend
	cd apps/api && uv run ruff check . && uv run mypy src

api-fmt: ## format backend
	cd apps/api && uv run ruff format . && uv run ruff check --fix .

# ---- flutter app --------------------------------------------------------

.PHONY: app-run app-test app-analyze app-fmt
app-run: ## flutter run via FVM
	cd apps/app && fvm flutter run

app-test: ## flutter test
	cd apps/app && fvm flutter test

app-analyze: ## flutter analyze
	cd apps/app && fvm flutter analyze

app-fmt: ## dart format + dart fix
	cd apps/app && fvm dart fix --apply && fvm dart format .

# ---- combined -----------------------------------------------------------

.PHONY: test lint fmt
test: ai-test api-test app-test ## run every test suite

lint: ai-lint api-lint app-analyze ## lint everything

fmt: ai-fmt api-fmt app-fmt ## format everything

# ---- supabase / db ------------------------------------------------------

.PHONY: db-up db-down db-reset db-migrate db-new-migration
db-up: ## start local Supabase stack
	supabase start

db-down: ## stop local Supabase stack
	supabase stop

db-migrate: ## apply pending migrations
	supabase db push

db-new-migration: ## create a new empty migration (NAME=feature_x)
	supabase migration new $(NAME)

# ---- infra (production-equivalent compose) ------------------------------

.PHONY: up down logs
up: ## docker compose up the full stack
	cd infra && docker compose up -d --build

down: ## docker compose down
	cd infra && docker compose down

logs: ## tail docker compose logs
	cd infra && docker compose logs -f --tail=200
