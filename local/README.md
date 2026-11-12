# Local full stack (LOCAL DEVELOPMENT ONLY)

`local/compose.yaml` runs the whole IKIGAI ATLAS stack on a developer machine from the three sibling repositories.
It is the `local` environment of the environment model (project-instruction §15.1) and mirrors the Kubernetes
routing, so "works through the edge locally" means "works through the Ingress in a cluster".

```text
browser ──► edge (nginx:1.30-alpine, 127.0.0.1:8000)
              ├─ /api, /api/...             ──► backend  (atlas-microservices Dockerfile, :8080) ──► postgres (:5432)
              ├─ /actuator/health[/...]     ──► backend  (local-only, for smoke tests)
              └─ everything else            ──► frontend (atlas Dockerfile, nginx-unprivileged :8080)
```

## Services

| Service | Image / build | Host port | Notes |
|---|---|---|---|
| `postgres` | `postgres:18.6-alpine` | `127.0.0.1:${ATLAS_DB_PORT:-5432}` | db/user/password `atlas`/`atlas`/`atlas` — **local only**; named volume `postgres-data` |
| `backend` | build `../../atlas-microservices` → `atlas-backend:local` | not published | `SPRING_PROFILES_ACTIVE=dev`, datasource via `SPRING_DATASOURCE_*`; waits for a healthy database |
| `frontend` | build `../../atlas` → `atlas-frontend:local` | not published | static SPA served by nginx-unprivileged |
| `edge` | `nginx:1.30-alpine` + `edge/nginx.conf` | `127.0.0.1:${ATLAS_EDGE_PORT:-8000}` | the only entry point; starts once backend and frontend are healthy |

All published ports bind to `127.0.0.1`, never to all interfaces.

### Why the backend runs with the `dev` profile, not `local`

The backend's `local` profile enables `spring-boot-docker-compose`, which starts
`atlas-microservices/compose.yaml` itself. That is the right tool for `./mvnw spring-boot:run`, but wrong inside a
container. The containerised backend therefore uses `dev` and gets its datasource explicitly through
`SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME` and `SPRING_DATASOURCE_PASSWORD` (the same variables a cluster
provides from the `atlas-backend-db` Secret).

## Usage

Run everything from the `atlas-infra` repository root:

```bash
docker compose -f local/compose.yaml up --build -d     # build sibling images and start
docker compose -f local/compose.yaml ps                # health status of every service
docker compose -f local/compose.yaml logs -f backend   # follow logs of one service
curl -fsS http://127.0.0.1:8000/                       # frontend
curl -fsS http://127.0.0.1:8000/actuator/health        # backend health via the edge
docker compose -f local/compose.yaml down              # stop, keep the database volume
docker compose -f local/compose.yaml down -v           # stop and DELETE the local database volume
```

Connect to the database directly: `psql "postgresql://atlas:atlas@127.0.0.1:${ATLAS_DB_PORT:-5432}/atlas"`.

## Configuration

Copy `local/.env.example` to `local/.env` (git-ignored) to override:

| Variable | Default | Purpose |
|---|---|---|
| `ATLAS_EDGE_PORT` | `8000` | host port of the edge proxy |
| `ATLAS_DB_PORT` | `5432` | host port of PostgreSQL (use e.g. `5433` if `atlas-microservices/compose.yaml` or a native PostgreSQL already uses 5432) |
| `ATLAS_BACKEND_PROFILE` | `dev` | Spring profile of the backend container (never `local`, see above) |
| `ATLAS_BACKEND_DIR` | `../../atlas-microservices` | backend build context, relative to `local/` or absolute |
| `ATLAS_FRONTEND_DIR` | `../../atlas` | frontend build context, relative to `local/` or absolute |

## What the sibling repositories must provide

| | Backend (`atlas-microservices/Dockerfile`) | Frontend (`atlas/Dockerfile`) |
|---|---|---|
| Location | repository root | repository root |
| Runtime base | `eclipse-temurin:21-jre-noble` | `nginxinc/nginx-unprivileged:1.30-alpine` |
| Port | `8080` | `8080` |
| Health | `/actuator/health/{liveness,readiness}` | `GET /healthz` → 200 |
| User | numeric non-root UID/GID `10001` | image default `101` (nginx) |
| Filesystem | writes only to `/tmp` (read-only root FS in Kubernetes) | writes only to `/tmp` (and `/var/cache/nginx`) |
| Tools for health checks | `curl` (present in the base image) | `curl` (present in the base image) |
| Behaviour | reads `SPRING_PROFILES_ACTIVE` and `SPRING_DATASOURCE_*`; graceful shutdown on SIGTERM | SPA fallback to `index.html`; no upstream proxying (the edge/Ingress routes `/api`) |

## Future: local identity provider (Phase 9)

Authentication is Phase 9 and the identity provider is an open decision (project-instruction §21, item 1). When it is
decided, an optional Keycloak service may be added under a Compose profile (`docker compose --profile auth up`). A
commented sketch is at the bottom of `compose.yaml`; it is intentionally not active.

## Troubleshooting

See [docs/runbooks/local-development.md](../docs/runbooks/local-development.md).
