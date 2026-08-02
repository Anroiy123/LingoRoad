#!/bin/sh
set -eu

daily=/backups/daily
weekly=/backups/weekly
metrics=/metrics/lingoroad_backup.prom
mkdir -p "$daily" "$weekly" /metrics

failure() {
  printf 'lingoroad_backup_last_failure 1\n' > "$metrics.tmp"
  mv "$metrics.tmp" "$metrics"
}
trap failure INT TERM HUP EXIT

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
file="$daily/lingoroad-$timestamp.dump"
pg_dump --format=custom --file="$file"
name=$(basename "$file")
(cd "$daily" && sha256sum "$name" > "$name.sha256")

if [ "$(date -u +%u)" = "7" ]; then
  cp "$file" "$weekly/$name"
  (cd "$weekly" && sha256sum "$name" > "$name.sha256")
fi

prune_backups() {
  directory=$1
  keep=$2
  count=$(find "$directory" -maxdepth 1 -type f -name '*.dump' | wc -l)
  overflow=$((count - keep))
  [ "$overflow" -gt 0 ] || return 0
  find "$directory" -maxdepth 1 -type f -name '*.dump' | sort | head -n "$overflow" |
    while IFS= read -r dump; do
      rm -f "$dump" "$dump.sha256"
    done
}

prune_backups "$daily" 7
prune_backups "$weekly" 4
{
  printf 'lingoroad_backup_last_failure 0\n'
  printf 'lingoroad_backup_last_success_timestamp_seconds %s\n' "$(date -u +%s)"
} > "$metrics.tmp"
mv "$metrics.tmp" "$metrics"
trap - INT TERM HUP EXIT
