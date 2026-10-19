#!/usr/bin/env bash
# Feelcoin Pool V2: isolated, private PostgreSQL staging only.
# Does not run Miningcore, connect to wallet RPC or change production.
set -euo pipefail
umask 077
BASE="$HOME/feelcoin-pool-v2-staging"
if [[ -e "$BASE/compose.yaml" || -e "$BASE/.env" ]]; then
  echo "STOP: existing staging files detected at $BASE; leaving them unchanged" >&2
  exit 1
fi
command -v docker >/dev/null
docker compose version >/dev/null
command -v openssl >/dev/null
if ! docker info >/dev/null 2>&1; then
  echo "STOP: Docker daemon inaccessible" >&2; exit 1
fi
if docker ps -a --format '{{.Names}}' | grep -qx 'feelcoin-pool-v2-postgres'; then
  echo 'STOP: Pool V2 container name already exists' >&2; exit 1
fi
mkdir -p "$BASE"
trap 'echo "Setup stopped; inspect $BASE for partial files" >&2' ERR
PW="$(openssl rand -hex 32)"
printf 'POSTGRES_PASSWORD=%s\n' "$PW" > "$BASE/.env"
chmod 600 "$BASE/.env"
cat > "$BASE/compose.yaml" <<'YAML'
name: feelcoin-pool-v2
services:
  postgres:
    image: postgres:17
    container_name: feelcoin-pool-v2-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: feelcoin_pool_v2
      POSTGRES_USER: feelcoin_pool_v2
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?required}
    volumes:
      - feelcoin_pool_v2_pgdata:/var/lib/postgresql/data
    networks:
      - v2_internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U feelcoin_pool_v2 -d feelcoin_pool_v2"]
      interval: 10s
      timeout: 5s
      retries: 6
    cpus: 0.50
    mem_limit: 512m
    security_opt:
      - no-new-privileges:true
networks:
  v2_internal:
    internal: true
volumes:
  feelcoin_pool_v2_pgdata:
YAML
chmod 600 "$BASE/compose.yaml"
cd "$BASE"
docker compose config --quiet
echo '=== Configuration validated ==='
echo 'No ports published. No wallet access. No production service changes.'
echo 'To start isolated database: cd ~/feelcoin-pool-v2-staging && docker compose up -d'
echo 'To check health: docker inspect --format "{{.State.Health.Status}}" feelcoin-pool-v2-postgres'
