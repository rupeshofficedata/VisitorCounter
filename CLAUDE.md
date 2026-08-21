# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A minimal single-file Flask app (`app.py`) that increments and returns a
page-view counter. It has two backends switched by the `USE_REDIS` env var:

- `USE_REDIS=true` (default, "prod"): counter lives in Redis (`INCR hits`),
  with retry logic (5 attempts, 0.5s sleep between) so the app tolerates
  Redis not being ready yet at container startup.
- `USE_REDIS=false` ("dev"): counter is a plain in-process global int —
  resets on restart, not shared across workers/processes.

There is no test suite, no linter config, and no build step in this repo.

## Running

Everything runs through Docker Compose profiles defined in `docker-compose.yml`:

```bash
# Dev mode: in-memory counter, no Redis, app on http://localhost:5001
docker compose --profile dev up --build

# Prod mode: Redis-backed counter, app on http://localhost:5000
docker compose --profile prod up --build
```

Without Docker:

```bash
pip install -r requirements.txt
USE_REDIS=false python app.py   # in-memory counter
USE_REDIS=true python app.py    # requires Redis reachable at host "redis"
```

The Flask dev server binds `0.0.0.0:5000` with `debug=True` — this is the
same entrypoint used in both dev and prod Docker profiles (`CMD ["python", "app.py"]`
in the `Dockerfile`), i.e. there is no separate WSGI/production server config.

## Architecture notes

- `redis` connection in `app.py` hardcodes `host='redis'` — this only
  resolves inside the Compose network (service name `redis`); running
  `USE_REDIS=true` outside Compose requires a reachable host named `redis`
  (e.g. via `/etc/hosts` or `--network` alias), not `localhost`.
- The Redis client is instantiated at import time; the in-memory `local_hits`
  global only exists when `USE_REDIS=false`, so the two code paths are not
  interchangeable — don't add logic that assumes both are always defined.
- `Dockerfile` runs as a non-root `appuser` (created via `useradd`), with
  deps installed before the app code is copied in for layer caching.
