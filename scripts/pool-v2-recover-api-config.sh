#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/feelcoin-pool-v2-staging"
CFG="$ROOT/runtime-private/config.json"
NAME=feelcoin-pool-v2-stratum-test
IMG=feelcoin-miningcore-v2-guarded:compile-only
test -f "$CFG"
python3 - "$CFG" <<'PY'
import sys,json,pathlib
p=pathlib.Path(sys.argv[1]); c=json.loads(p.read_text())
assert not c['paymentProcessing']['enabled']
assert len(c['pools'])==1 and not c['pools'][0]['paymentProcessing']['enabled']
assert c['pools'][0]['ports']['5252']['listenAddress']=='127.0.0.1'
c['api']={'enabled':False,'legacyNullValueHandling':False}
c['notifications']={'enabled':False,'admin':{'enabled':False},'pushover':{'enabled':False}}
p.write_text(json.dumps(c,indent=2)+'\n')
p.chmod(0o644)
print('PASS: explicit API object and disabled notifications')
PY
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" --network host --cpus 1.25 --memory 1500m \
--security-opt no-new-privileges:true --cap-drop ALL \
--mount "type=bind,src=$CFG,dst=/app/build/config.json,readonly" \
--entrypoint /bin/sh "$IMG" \
-c 'cd /app/build && timeout 900 dotnet Miningcore.dll -c /app/build/config.json' >/dev/null
sleep 12
echo '=== STAGING ==='
if ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
 docker logs "$NAME" --tail 35 2>&1
 exit 1
fi
docker logs "$NAME" --tail 12 2>&1
ss -lnt | grep ':5252 ' || { echo 'Port 5252 not listening'; exit 1; }
echo '=== PRODUCTION ==='
test "$(systemctl is-active feelcoin-pool.service)" = active
echo 'READY: localhost 5252 live; no payouts'
