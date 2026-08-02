#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: deploy.sh <image-sha>" >&2
  exit 2
fi

sha=$1
case "$sha" in
  *[!0-9a-f]*|'') echo "image SHA must be lowercase hexadecimal" >&2; exit 2 ;;
esac
if [ "${#sha}" -ne 40 ]; then
  echo "image SHA must contain exactly 40 hexadecimal characters" >&2
  exit 2
fi

root=/opt/lingoroad/deploy
compose="$root/compose.production.yml"
env_file="$root/.env.production"
prefix=${IMAGE_PREFIX:?IMAGE_PREFIX is required}
previous="$root/.previous-images"

cd "$root"
test -s "$env_file"

read_env_value() {
  key=$1
  value=$(sed -n "s/^${key}=//p" "$env_file" | tail -n 1)
  test -n "$value" || { echo "$key is missing from .env.production" >&2; exit 2; }
  printf '%s' "$value"
}

domain=$(read_env_value DOMAIN)
case "$domain" in
  *[!A-Za-z0-9.-]*|.*|*..*|*.) echo "DOMAIN must be a plain DNS hostname" >&2; exit 2 ;;
esac

capture_previous() {
  : > "$previous.tmp"
  for service in api ml admin; do
    container=$(docker compose --env-file "$env_file" -f "$compose" ps -q "$service")
    if [ -n "$container" ]; then
      image=$(docker inspect --format '{{.Config.Image}}' "$container")
      printf '%s=%s\n' "$(echo "$service" | tr '[:lower:]' '[:upper:]')_IMAGE" "$image" >> "$previous.tmp"
    fi
  done
  if [ -s "$previous.tmp" ]; then mv "$previous.tmp" "$previous"; else rm -f "$previous.tmp"; fi
}

capture_previous
export API_IMAGE="$prefix/lingoroad-api:$sha"
export ML_IMAGE="$prefix/lingoroad-ml:$sha"
export ADMIN_IMAGE="$prefix/lingoroad-admin:$sha"

docker compose --env-file "$env_file" -f "$compose" config --quiet
docker compose --env-file "$env_file" -f "$compose" pull --ignore-buildable
docker compose --env-file "$env_file" -f "$compose" build backup
docker compose --env-file "$env_file" -f "$compose" up -d --remove-orphans

healthy=false
for _ in $(seq 1 20); do
  if curl --fail --silent --show-error --connect-timeout 3 --max-time 5 \
       "https://$domain/api/ready" >/dev/null &&
     docker compose --env-file "$env_file" -f "$compose" exec -T ml \
       python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8001/ready', timeout=4)"; then
    healthy=true
    break
  fi
  sleep 5
done

if [ "$healthy" != true ]; then
  echo "health check failed; rolling back images" >&2
  if [ -s "$previous" ]; then
    API_IMAGE=$(sed -n 's/^API_IMAGE=//p' "$previous" | tail -n 1)
    ML_IMAGE=$(sed -n 's/^ML_IMAGE=//p' "$previous" | tail -n 1)
    ADMIN_IMAGE=$(sed -n 's/^ADMIN_IMAGE=//p' "$previous" | tail -n 1)
    for image in "$API_IMAGE" "$ML_IMAGE" "$ADMIN_IMAGE"; do
      case "$image" in
        ''|*[!A-Za-z0-9_./:@+-]*) echo "invalid rollback image reference" >&2; exit 1 ;;
      esac
    done
    export API_IMAGE ML_IMAGE ADMIN_IMAGE
    docker compose --env-file "$env_file" -f "$compose" up -d --remove-orphans
  fi
  exit 1
fi

printf '%s\n' "$sha" > "$root/.deployed-sha"
docker image prune -f --filter until=168h
