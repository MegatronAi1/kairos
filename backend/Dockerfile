# Kairos backend: FastAPI + engines. Build context is the repo root.
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends libgomp1 curl \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir uv==0.5.11

WORKDIR /app
ENV UV_LINK_MODE=copy UV_COMPILE_BYTECODE=1 PYTHONUNBUFFERED=1

# Dependencies first (cached layer), then sources.
COPY pyproject.toml uv.lock ./
COPY ml/pyproject.toml ml/pyproject.toml
COPY backend/pyproject.toml backend/pyproject.toml
COPY ml/kairos_ml ml/kairos_ml
COPY ml/config ml/config
COPY backend/app backend/app
RUN uv sync --frozen --no-dev --all-packages

# data/ and artifacts/ are mounted at runtime (gitignored; never baked into the image).
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=60s --retries=6 \
    CMD curl -fsS http://localhost:8000/api/v1/healthz || exit 1
CMD ["uv", "run", "--no-sync", "uvicorn", "app.main:app", "--app-dir", "backend", "--host", "0.0.0.0", "--port", "8000"]
