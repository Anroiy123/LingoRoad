# Production deployment and release runbook

## Required external inputs

Phase 7 cannot perform a real release until these are configured outside Git:

- VPS with Docker Engine/Compose, SSH user and `/opt/lingoroad` write access.
- Domain/DNS pointing to the VPS and inbound TCP 80/443 plus UDP 443.
- GitHub `production` environment with required reviewers.
- Secrets: `VPS_HOST`, `VPS_USER`, `VPS_SSH_PRIVATE_KEY`,
  `VPS_SSH_KNOWN_HOSTS`, `PRODUCTION_ENV_FILE`, Android keystore/password/alias.
- Variable `PROD_API_BASE_URL` using `https://`.
- VPS authenticated to GHCR with read-only package permission.

Never commit `.env.production`, keystores, passwords, tokens or private keys.
Start from `deploy/.env.production.example` and store the completed file as the
`PRODUCTION_ENV_FILE` environment secret.

## CI and image lifecycle

`Quality Gate` runs backend build/test/PostgreSQL migration, ML tests/manifest,
Flutter analyze/test/dev APK, Admin lint/test/build/Playwright, dependency scans,
secret scan and container builds. Protect `main` so every job is required.

After a green push to `main`, `Publish Production Images` builds API, ML and
Admin images and pushes immutable GHCR tags equal to the full commit SHA. Do not
deploy `latest`.

Production deploy is manual:

1. Open `Deploy Production`, enter a green `main` image SHA and pass the
   `production` environment approval.
2. The workflow uploads the versioned Compose/config and secret environment.
3. The VPS pulls SHA-tagged images. The one-shot `api-migrate` service applies
   backward-compatible migrations, then the separate `content-seed` job imports
   the idempotent versioned bundle before API traffic starts.
4. Caddy obtains/renews HTTPS and routes `/api/*` to the API, `/ops/*` to
   Grafana and all other traffic to Admin.
5. The POSIX-shell deploy script probes `https://DOMAIN/api/ready` and ML
   component readiness separately for up to 100 seconds. Failure restores the
   three previously running image references.

Database changes must follow expand → backfill → contract. A rollback only
changes image tags; it does not reverse a destructive migration.

## Topology and secrets

Only Caddy exposes host ports. API, ML, PostgreSQL, MinIO and observability stay
on internal networks. ML requires the internal token; PostgreSQL/MinIO/Grafana
credentials come from `.env.production`. The speaking temp directory is a
64 MiB tmpfs outside web root and never enters backups.

MinIO is provisioned as S3-compatible storage but the current versioned lesson
audio is packaged as public API content. Do not claim that MinIO stores lesson
content until an object-storage adapter is implemented.

## Monitoring and logs

- API emits OTLP traces/metrics and JSON console logs.
- OpenTelemetry Collector exposes metrics to Prometheus.
- Blackbox exporter probes API/ML health; node/postgres exporters cover disk/DB.
- Promtail ships Docker JSON logs to Loki; Grafana provisions Prometheus/Loki.
- Prometheus evaluates rules for unhealthy services, health latency, PostgreSQL,
  disk space and failed/stale backups. No Alertmanager or notification delivery
  is provisioned by this repository; operators must wire Alertmanager (or an
  equivalent receiver) and test routing before go-live.
- Loki retention is 30 days. Security/Admin audit rows remain 90 days according
  to `docs/privacy-retention.md`.

## Backup and restore drill

The backup container runs `pg_dump --format=custom` daily at 02:15 UTC, writes
SHA-256 sidecars, keeps seven daily and four weekly windows, and exports a
success/failure metric. Copy the backup volume off the VPS with encrypted
storage; a same-disk backup is not disaster recovery.

Quarterly restore drill:

1. Run `deploy/scripts/restore-drill.sh`; it selects the newest daily dump
   and verifies its SHA-256 sidecar.
2. The script restores only to `lingoroad_restore_drill`, checks EF migration
   history, then removes the drill database unless `KEEP_RESTORE_DRILL=true`.
3. Apply current migrations, run the clean-account learner loop and Admin smoke.
4. Replay account-deletion receipts newer than the dump timestamp.
5. Record dump ID, commit SHA, duration, row-count checks and smoke output.

Raw speaking audio must never exist in the dump or backup volume.

The backup image currently runs BusyBox crond as root so it can use the system
crontab. Its only writable mounts are the dedicated backup and metrics volumes;
changing this requires a tested non-root scheduler and volume ownership
migration. This is an accepted operational constraint, not a security claim.

## Android release

Android flavors are:

| Flavor | Application ID | Name | Network policy |
|---|---|---|---|
| `dev` | `com.lingoroad.app.dev` | LingoRoad Dev | HTTP allowed in debug manifest |
| `staging` | `com.lingoroad.app.staging` | LingoRoad Staging | Pass an HTTPS staging URL for release |
| `prod` | `com.lingoroad.app` | LingoRoad | `AppConfig` rejects non-HTTPS URLs |

`Android Signed Release` reconstructs the upload keystore from GitHub secrets,
fails closed when signing material/HTTPS URL is missing, builds split APKs and
an AAB, uploads artifacts for 30 days and removes signing files. Install/smoke
the APK on MuMu and a real Android device, then test the AAB through Google Play
Internal Testing before promotion. That device/store smoke remains an external
release gate and cannot be marked complete by CI build output alone.
