#!/bin/sh
set -eu

root="${DEPLOY_ROOT:-/opt/lingoroad/deploy}"
compose="$root/compose.production.yml"
env_file="$root/.env.production"
backup_path="${1:-}"
target_db="${2:-lingoroad_restore_drill}"
if [ -z "$backup_path" ]; then
  echo "usage: restore-postgres.sh <backup-path-in-volume> [target-db]" >&2
  exit 2
fi
case "$backup_path" in
  /backups/daily/*.dump|/backups/weekly/*.dump) ;;
  *) echo "backup must be in /backups/daily or /backups/weekly" >&2; exit 2 ;;
esac
case "$target_db" in
  *_restore_drill) ;;
  *)
    test "${ALLOW_PRODUCTION_RESTORE:-false}" = true ||
      { echo "refusing non-drill target without ALLOW_PRODUCTION_RESTORE=true" >&2; exit 3; }
    ;;
esac
docker compose --env-file "$env_file" -f "$compose" exec -T backup sh -eu -c '
  dump="$1"
  database="$2"
  cd "$(dirname "$dump")"
  sha256sum -c "$(basename "$dump").sha256"
  dropdb --if-exists "$database"
  createdb "$database"
  pg_restore --exit-on-error --no-owner --no-privileges --dbname="$database" "$dump"
  psql --dbname="$database" --set=ON_ERROR_STOP=1 \
    --command="SELECT COUNT(*) AS migration_count FROM \"__EFMigrationsHistory\";"
' -- "$backup_path" "$target_db"
echo "Restore completed and EF migration history validated in $target_db"
