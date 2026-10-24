# Works with GNU make or mingw32-make on Windows. Recipes only call uv / pnpm / flutter.
UV ?= uv

.PHONY: setup data train eval dev up test lint tokens

setup:
	$(UV) sync --all-packages
	cd web && pnpm install
	cd mobile && flutter pub get

data:
	$(UV) run python -m kairos_ml.data.inspect

train:
	$(UV) run python ml/scripts/train_all.py

eval:
	$(UV) run python ml/scripts/evaluate_all.py

dev:
	$(UV) run uvicorn app.main:app --app-dir backend --reload --port 8000

up:
	docker compose up --build

tokens:
	node design/build-tokens.mjs

test:
	$(UV) run pytest
	cd web && pnpm test

lint:
	$(UV) run ruff check ml backend
	$(UV) run ruff format --check ml backend
	$(UV) run mypy ml/kairos_ml backend/app
