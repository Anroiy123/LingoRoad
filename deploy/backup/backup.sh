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
sha256sum "$file" > "$file.sha256"

if [ "$(date -u +%u)" = "7" ]; then
  cp "$file" "$weekly/"
  cp "$file.sha256" "$weekly/"
fi

find "$daily" -type f -mtime +7 -delete
find "$weekly" -type f -mtime +28 -delete
{
  printf 'lingoroad_backup_last_failure 0\n'
  printf 'lingoroad_backup_last_success_timestamp_seconds %s\n' "$(date -u +%s)"
} > "$metrics.tmp"
mv "$metrics.tmp" "$metrics"
trap - INT TERM HUP EXIT
