#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/feelcoin-pool-v2-staging"
NAME="feelcoin-pool-v2-stratum-test"
IMAGE="feelcoin-miningcore-v2-guarded:compile-only"
CFG="$ROOT/runtime-private/config.json"
test "$(systemctl is-active feelcoin-pool.service)" = active
test -f "$CFG"
python3 - "$CFG" <<'PY'
from pathlib import Path
import json,sys
p=Path(sys.argv[1]); cfg=json.loads(p.read_text())
assert cfg['paymentProcessing']['enabled'] is False
assert len(cfg['pools'])==1 and cfg['pools'][0]['paymentProcessing']['enabled'] is False
assert cfg['pools'][0]['id']=='feel-v2-test'
assert cfg['pools'][0]['ports']['5252']['listenAddress']=='127.0.0.1'
cfg['notifications']={'enabled':False,'admin':{'enabled':False},'pushover':{'enabled':False}}
p.write_text(json.dumps(cfg,indent=2)+'\n')
p.chmod(0o644)
print('PASS: fixed missing notifications object; payouts disabled')
PY
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" --network host --cpus 1.25 --memory 1500m \
  --security-opt no-new-privileges:true --cap-drop ALL \
  --mount "type=bind,src=$CFG,dst=/app/build/config.json,readonly" \
  --entrypoint /bin/sh "$IMAGE" \
  -c 'cd /app/build && timeout 900 dotnet Miningcore.dll -c /app/build/config.json' >/dev/null
sleep 12
if ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
  echo 'STAGING STARTUP FAILED:'
  docker logs "$NAME" --tail 45 2>&1 | sed -E 's/("password" *: *)"[^"]*"/\1"[REDACTED]"/Ig'
  exit 1
fi
echo '=== V2 STAGING LOG ==='
docker logs "$NAME" --tail 25 2>&1 | sed -E 's/("password" *: *)"[^"]*"/\1"[REDACTED]"/Ig'
echo '=== LISTENER ==='
ss -lnt | grep ':5252 ' || { echo 'Port 5252 not listening yet'; exit 1; }
echo '=== PRODUCTION ==='
systemctl is-active feelcoin-pool.service
echo 'READY: localhost-only V2 test available for 15 minutes; payouts disabled'
