# Visitor Counter

A minimal Flask web app that counts and displays page views. It can run
against Redis for a persistent, shared counter (production) or with a
simple in-memory counter (development, no dependencies required).

## How it works

- `GET /` increments a hit counter and returns the current count.
- When `USE_REDIS=true`, the counter is stored in Redis (`INCR hits`),
  with retry logic (5 attempts, 0.5s apart) to ride out Redis being briefly
  unavailable at startup.
- When `USE_REDIS=false`, the counter is a plain in-process variable — it
  resets whenever the app restarts and isn't shared across workers.
- `GET /healthz` returns a plain `OK` with no side effects — used by the
  Dockerfile's `HEALTHCHECK` so health probes don't inflate the counter.
- `GET /version` returns `{"version": "<APP_VERSION>"}` as JSON.

## Requirements

- Python 3.13+ (see `Dockerfile`)
- [Docker](https://www.docker.com/) and Docker Compose (recommended way to run this)
- Or, for running locally without Docker: `pip install -r requirements.txt`,
  and Redis running locally if `USE_REDIS=true`.

## Running with Docker Compose

The `docker-compose.yml` defines two profiles:

**Development** — local in-memory counter, no Redis:

```bash
docker compose --profile dev up --build
```

App available at http://localhost:5001

**Production** — Redis-backed counter:

```bash
docker compose --profile prod up --build
```

App available at http://localhost:5000, with Redis running alongside
(data persisted in the `redis_data` volume).

## Running locally without Docker

```bash
pip install -r requirements.txt

# Dev mode (in-memory counter)
USE_REDIS=false python app.py

# Prod mode (requires a Redis instance reachable at host "redis")
USE_REDIS=true python app.py
```

The app listens on `0.0.0.0:5000` by default.

## Configuration

| Env var       | Default | Description                                      |
|---------------|---------|---------------------------------------------------|
| `USE_REDIS`   | `true`  | `true` to use Redis, `false` for an in-memory counter |
| `APP_VERSION` | `dev`   | Reported by `GET /version`; set to a real version/tag in CI/CD builds |

## Project structure

```
.
├── app.py              # Flask application
├── requirements.txt    # Python dependencies
├── Dockerfile           # Container image (runs as non-root user)
├── docker-compose.yml  # dev/prod service definitions
└── .gitignore
```
