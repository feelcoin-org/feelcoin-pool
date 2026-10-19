#!/usr/bin/env bash
# Deploy FEEL V2 local-only *experimental* stratum for an Ubuntu SSH-tunnel test.
# NO production cutover, NO wallet RPC, NO payouts. Block candidates, if found,
# are submitted to mainnet under the existing public pool address. Run briefly.
set -euo pipefail
umask 077
ROOT="$HOME/feelcoin-pool-v2-staging"; SRC="$ROOT/miningcore-feelcoin-candidate"
NAME="feelcoin-pool-v2-stratum-test"; DB="feelcoin-pool-v2-postgres"
IMAGE="feelcoin-miningcore-v2-guarded:compile-only"
CONFIG="$ROOT/v2-local-test.json"
trap 'echo "STAGING ERROR: production was not altered. Check docker logs feelcoin-pool-v2-stratum-test" >&2' ERR
test "$(systemctl is-active feelcoin-pool.service)" = active
test "$(docker inspect -f '{{.State.Health.Status}}' "$DB")" = healthy
test -f "$SRC/src/Miningcore/Persistence/Postgres/Scripts/createdb.sql"
test -f "$ROOT/.env"
test -f "$HOME/feelcoin-pool/pool.conf"
if docker container inspect "$NAME" >/dev/null 2>&1; then echo "STOP: staging container already exists. Inspect it rather than replacing."; exit 1; fi
docker image inspect "$IMAGE" >/dev/null
DBIP="$(docker inspect "$DB" -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')"
[[ "$DBIP" =~ ^[0-9.]+$ ]] || { echo "STOP: couldn't resolve private staging DB"; exit 1; }
PW="$(sed -n 's/^POSTGRES_PASSWORD=//p' "$ROOT/.env")"
test -n "$PW"
# Safe and idempotent staging schema only
if ! docker exec "$DB" psql -U feelcoin_pool_v2 -d feelcoin_pool_v2 -Atqc "select to_regclass('public.shares')" | grep -qx shares; then
  sed '/^SET ROLE miningcore;/d' "$SRC/src/Miningcore/Persistence/Postgres/Scripts/createdb.sql" | docker exec -i "$DB" psql -v ON_ERROR_STOP=1 -U feelcoin_pool_v2 -d feelcoin_pool_v2 >/dev/null
fi
python3 - "$ROOT" "$SRC" "$DBIP" "$PW" <<'PY'
from pathlib import Path
import json,re,sys,ipaddress
root,src,dbip,pw=sys.argv[1:]
ipaddress.ip_address(dbip)
p=Path.home()/'feelcoin-pool/pool.conf'
m=re.search(r'^\s*pool-wallet\s*=\s*(\S+)\s*$',p.read_text(),re.M)
if not m or not (90<=len(m.group(1))<=130): raise SystemExit('STOP: public pool wallet could not be resolved')
address=m.group(1)
coins=json.loads((Path(src)/'src/Miningcore/coins.json').read_text())
assert coins['feelcoin']['addressPrefix']==84 and coins['feelcoin']['hash']=='randomx'
guard=(Path(src)/'src/Miningcore/Blockchain/Cryptonote/CryptonotePayoutHandler.cs').read_text()
assert 'FEEL payout accounting blocked' in guard
config={'logging':{'level':'info','enableConsoleLog':True,'enableConsoleColors':False},
  'persistence':{'postgres':{'host':dbip,'port':5432,'user':'feelcoin_pool_v2','password':pw,'database':'feelcoin_pool_v2'}},
  'paymentProcessing':{'enabled':False},
  'pools':[{'id':'feel-v2-test','enabled':True,'coin':'feelcoin','randomXRealm':'feel-v2-test',
    'address':address,'rewardRecipients':[],
    'ports':{'5252':{'listenAddress':'127.0.0.1','difficulty':100,'name':'Local Ubuntu FEEL Test',
                       'varDiff':{'minDiff':100,'maxDiff':None,'targetTime':15,'retargetTime':60,'variancePercent':30}}},
    'daemons':[{'host':'127.0.0.1','port':35781}],
    'paymentProcessing':{'enabled':False,'minimumPayment':5.0,'payoutScheme':'PPLNS',
                         'payoutSchemeConfig':{'factor':2.0}}}]}
Path(root+'/v2-local-test.json').write_text(json.dumps(config,indent=2)+'\n')
Path(root+'/v2-local-test.json').chmod(0o600)
print('PASS: isolated pool config created, localhost:5252, payment processing disabled')
print('NOTICE: block candidates, if mined, pay legacy pool wallet; no real block is guaranteed during test')
PY
# image is a builder stage with /app/build/Miningcore.dll; verify
docker run --rm --network host --entrypoint /bin/sh "$IMAGE" -c 'test -f /app/build/Miningcore.dll'
# limited-duration container; mount only a read-only generated config
docker run -d --name "$NAME" --network host --cpus 1.25 --memory 1500m \
  --security-opt no-new-privileges:true --cap-drop ALL \
  --mount "type=bind,src=$CONFIG,dst=/app/build/config.json,readonly" \
  --entrypoint /bin/sh "$IMAGE" -c 'cd /app/build && timeout 900 dotnet Miningcore.dll -c /app/build/config.json' >/dev/null
sleep 9
echo '=== TEST STATUS ==='
if ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then docker logs "$NAME" --tail 65 || true; echo 'FAILED: stage stopped'; exit 1; fi
docker logs "$NAME" --tail 35 2>&1 | sed -E 's/(password|secret|token)([^, ]*)/REDACTED/Ig'
echo '=== LOCAL STRATUM ==='
ss -lnt | grep ':5252 ' || { echo 'STOP: local port did not open, inspect container logs'; exit 1; }
test "$(systemctl is-active feelcoin-pool.service)" = active
echo 'READY: experimental localhost:5252 for up to 15 minutes. No public V2 port, no payouts.'
echo 'Ubuntu SSH tunnel: ssh -N -L 5252:127.0.0.1:5252 feeladmin@node1.feelcoin.org'
echo 'Then point XMRig on Ubuntu to 127.0.0.1:5252 using a FEEL wallet address.'
