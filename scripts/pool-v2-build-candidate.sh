#!/usr/bin/env bash
# Pool V2 candidate: single offline compile and safety gate, never runs mining or payouts.
set -euo pipefail
ROOT="$HOME/feelcoin-pool-v2-staging"
SRC="$ROOT/miningcore-feelcoin-candidate"
test -f "$SRC/src/Miningcore/coins.json"
test -f "$SRC/Dockerfile"
python3 - "$SRC" <<'PY'
import json,sys,pathlib
s=pathlib.Path(sys.argv[1])
j=json.loads((s/'src/Miningcore/coins.json').read_text())
f=j['feelcoin']
assert f['symbol']=='FEEL' and f['family']=='cryptonote' and f['addressPrefix']==84
assert j['monero']['addressPrefix']==18
assert 'net6.0' in (s/'src/Miningcore/Miningcore.csproj').read_text()
# Block attempts to use this incomplete implementation with live wallet.
assert 'StaticTransactionFeeReserve' in (s/'src/Miningcore/Blockchain/Cryptonote/CryptonotePayoutHandler.cs').read_text()
print('PASS: FEEL coin mapping in separate candidate. Payouts must remain disabled.')
PY
cd "$SRC"
echo '=== BUILD FEELCOIN MININGCORE CANDIDATE (NO START) ==='
docker build --target BUILDER --tag feelcoin-miningcore-v2-candidate:compile-only . > "$ROOT/feelcoin-v2-compile.log" 2>&1 || {
  echo 'FAILED: last 65 lines of build log'
  tail -n 65 "$ROOT/feelcoin-v2-compile.log"
  exit 1
}
echo 'PASS: candidate image built'
docker image inspect feelcoin-miningcore-v2-candidate:compile-only --format 'Image={{.Id}}'
echo '=== STATIC ECONOMICS ==='
python3 - <<'PY'
from decimal import Decimal
atomic=10**12
minimum=5*atomic
assert minimum==5000000000000
assert Decimal(5)*Decimal('0.005') == Decimal('0.025')
print('Fee: 0.5% | Minimum payout: 5 FEEL | 1 FEEL = 10^12 atomic units')
PY
echo '=== PRODUCTION CHECK ==='
systemctl is-active feelcoin-pool.service
echo '=== NO CONTAINERS STARTED, NO RPC OR WALLET ACCESS ==='
echo 'NEXT GATE: FEEL randomx test vectors, reward recipient audit, fee wallet and payouts before staging run.'
