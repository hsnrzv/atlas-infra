# Runbook: local development (full stack)

- Scope: the `local` environment, i.e. `local/compose.yaml` on a developer machine. There is no cloud or cluster
  access.
- Owner: @hsnrzv. Last verified: 2026-11-12. Docker Desktop with Compose v2 on macOS; both sibling Dockerfiles built;
  all four services healthy; edge routes checked with `curl`.

## Prerequisites

- Docker Engine or Docker Desktop with Compose v2 (`docker compose version`). Give Docker at least about 4 GiB of
  memory: the backend container alone is allowed up to 1 GiB in clusters and builds Maven and npm projects.
- The three repositories checked out side by side:

  ```text
  project-atlas/
    atlas/                 # frontend, Dockerfile at the root
    atlas-microservices/   # backend, Dockerfile at the root
    atlas-infra/           # this repository
  ```

- Internet access to the public registries: Docker Hub, `registry.npmjs.org` and Maven Central. Builds must not
  depend on a private mirror; the lockfile and wrapper of each repository point only to public registries.

## Start, check, stop

Run every command from the `atlas-infra` repository root.

```bash
docker compose -f local/compose.yaml up --build -d
docker compose -f local/compose.yaml ps            # wait until all four services show (healthy)

curl -fsS http://127.0.0.1:8000/ | grep -o '<title>[^<]*</title>'   # frontend through the edge
curl -fsS http://127.0.0.1:8000/actuator/health                     # {"groups":["liveness","readiness"],"status":"UP"}
curl -s -o /dev/null -w '%{http_code} %{content_type}\n' http://127.0.0.1:8000/api/v1/unknown
#   404 application/problem+json   -> /api reached the backend (an nginx 404 would be text/html)

docker compose -f local/compose.yaml down          # stop; keeps the database volume
```

The startup order is enforced by health checks: `postgres` (`pg_isready`) → `backend` (readiness endpoint) and
`frontend` (`/healthz`) → `edge`. The first build takes a few minutes; later builds use the layer cache.

## Common tasks

| Task | Command |
|---|---|
| Rebuild after code changes in a sibling repository | `docker compose -f local/compose.yaml up --build -d backend` (or `frontend`) |
| Follow logs | `docker compose -f local/compose.yaml logs -f backend` |
| Open a SQL shell | `docker compose -f local/compose.yaml exec postgres psql -U atlas -d atlas` |
| Show applied Flyway migrations | `docker compose -f local/compose.yaml exec postgres psql -U atlas -d atlas -c 'select version, description, success from atlas.flyway_schema_history'` |
| Connect from a host tool | `psql "postgresql://atlas:atlas@127.0.0.1:${ATLAS_DB_PORT:-5432}/atlas"` |
| Run with a different backend profile | `ATLAS_BACKEND_PROFILE=staging docker compose -f local/compose.yaml up -d backend` (never `local`, see `local/README.md`) |

## Reset the local database

The database lives in the named volume `atlas-local_postgres-data`. To start from an empty database, which then gets
re-migrated by Flyway on the next backend start:

```bash
docker compose -f local/compose.yaml down -v    # removes containers, network AND the database volume
docker compose -f local/compose.yaml up -d
```

`down -v` deletes all local data irreversibly. The data is throwaway by definition; never put real personal data into
the local stack.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Bind for 127.0.0.1:5432 failed: port is already allocated` or `address already in use` | `atlas-microservices/compose.yaml` (used by `./mvnw spring-boot:run`) or a native PostgreSQL already uses 5432 | `ATLAS_DB_PORT=5433 docker compose -f local/compose.yaml up -d`, or set it in `local/.env` (copy from `local/.env.example`). Find the holder with `lsof -nP -iTCP:5432 -sTCP:LISTEN` or `docker ps --filter publish=5432`. |
| Port 8000 already in use | another local server | `ATLAS_EDGE_PORT=8001 …` and use that port in the URLs |
| Edge returns `502 Bad Gateway` | backend or frontend is not running or not yet healthy | `docker compose -f local/compose.yaml ps`; check `logs backend`. The edge resolves upstreams per request, so it recovers on its own once the service is back. |
| Backend `unhealthy` or restarting | database not reachable, or a failing Flyway migration | `logs backend` and search for `flyway` or `ERROR`. For a broken local schema after editing an already-applied migration, reset the database (above). Never edit applied migrations; add a new one. |
| `failed to solve … npm ci … E401` / `Unable to authenticate` during the frontend build | the frontend lockfile references a private registry | Fix it in `atlas` (`npm run lockfile:check` must pass); the lockfile may only reference `registry.npmjs.org` |
| Build fails because the build context path does not exist | sibling repository not checked out next to this one | clone it, or point `ATLAS_FRONTEND_DIR` / `ATLAS_BACKEND_DIR` (relative to `local/` or absolute) at it. `config -q` does not detect this; only a build does. |
| Build is very slow or the JVM is OOM-killed | Docker Desktop memory too low | raise the Docker Desktop memory limit (≥ 4 GiB) |
| Changes not visible after a rebuild | browser cache for `index.html` | the frontend sends `Cache-Control: no-cache` for `index.html`; hard-reload. Hashed assets are immutable by design. |

## Clean up completely

```bash
docker compose -f local/compose.yaml down -v
docker image rm atlas-backend:local atlas-frontend:local
```

`down --rmi local` does not remove these two images because the services set an explicit `image:` name.
`down --rmi all` would also remove the shared `postgres` and `nginx` images. Base images (`postgres`, `nginx`,
`eclipse-temurin`, `node`) stay in the local cache; remove them with `docker image rm` if needed.

## Related

- [local/README.md](../../local/README.md): services, configuration variables, sibling Dockerfile expectations
- [PLAN-INFRASTRUCTURE-CICD.md](../plan/PLAN-INFRASTRUCTURE-CICD.md#local-development-stack)
