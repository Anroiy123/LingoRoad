#!/bin/sh
set -eu

root="${DEPLOY_ROOT:-/opt/lingoroad/deploy}"
compose="$root/compose.production.yml"
env_file="$root/.env.production"
latest="$(docker compose --env-file "$env_file" -f "$compose" exec -T backup sh -c "find /backups/daily -type f -name '*.dump' | sort | tail -n 1" | tr -d "\r")"
test -n "$latest" || { echo "no daily backup is available" >&2; exit 4; }
DEPLOY_ROOT="$root" "$root/scripts/restore-postgres.sh" "$latest" lingoroad_restore_drill
if [ "${KEEP_RESTORE_DRILL:-false}" != true ]; then
  docker compose --env-file "$env_file" -f "$compose" exec -T backup dropdb --if-exists lingoroad_restore_drill
fi
echo "Restore drill passed for $latest; record operator, duration and row checks."
