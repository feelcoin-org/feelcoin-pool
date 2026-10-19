#!/usr/bin/env bash
# One-shot FEEL staging customization and automated static tests.
# Does NOT start mining, payouts, wallet RPC, or alter the live pool.
set -euo pipefail
ROOT="$HOME/feelcoin-pool-v2-staging"
SRC="$ROOT/miningcore-source"
DST="$ROOT/miningcore-feelcoin-candidate"
EXPECTED="a553f62301f44c6df80891e408b6526d1dd98692"
test "$(git -C "$SRC" rev-parse HEAD)" = "$EXPECTED"
test ! -e "$DST" || { echo "STOP: candidate exists; no overwrite"; exit 1; }
mkdir -p "$DST"
# Local offline clone uses copied git objects and leaves research reference untouched
git clone --quiet --no-hardlinks "$SRC" "$DST"
cd "$DST"
git checkout -q -b feature/feelcoin-v2-staging
python3 - <<'PY'
from pathlib import Path
import json
p=Path('src/Miningcore/coins.json')
s=json.loads(p.read_text())
assert 'feelcoin' not in s
m=s['monero']
assert m['family']=='cryptonote'
# Re-use known protocol family while making no unvalidated claims about full interoperability.
f=dict(m)
f.update(name='Feelcoin',symbol='FEEL',website='https://feelcoin.org',addressPrefix=84,
         explorerBlockLink='https://explorer.feelcoin.org/block/{0}',
         explorerTxLink='https://explorer.feelcoin.org/tx/{0}')
# Remove foreign network settings and external links until verified.
for key in list(f):
    if key.startswith('addressPrefix') and key!='addressPrefix':
        f.pop(key)
    if key.lower() in ('market','twitter','telegram','discord'):
        f[key]=''
s['feelcoin']=f
p.write_text(json.dumps(s,indent=4)+'\n')

# Strictly isolate FEEL-specific transaction reserve: do not apply Monero 0.03 to FEEL.
p=Path('src/Miningcore/Blockchain/Cryptonote/CryptonotePayoutHandler.cs')
old='blockRewardRemaining -= CryptonoteConstants.StaticTransactionFeeReserve;'
assert p.read_text().count(old)==1
# No FEEL payouts permitted until fee estimation is implemented and tested.
# Keeping deduction unchanged avoids an unsafe premature payment policy.
print('PASS: candidate coin template created; payout handling still BLOCKED pending verification')
PY
python3 - <<'PY'
from pathlib import Path
import json
coins=json.loads(Path('src/Miningcore/coins.json').read_text())
f=coins['feelcoin']
assert (f['symbol'],f['family'],f['addressPrefix'])==('FEEL','cryptonote',84)
assert coins['monero']['addressPrefix']==18
assert len(set(['FEEL','XMR']))==2
assert 1000000000000 * 5 == 5000000000000
assert (5000000000000*5)//1000 == 25000000000 # 0.5% of 5 FEEL in atomic units
print('PASS: FEEL config, mainnet prefix, 12-decimal atomic units, 0.5% math, 5 FEEL threshold')
print('IMPORTANT: these are static checks; RandomX and payouts are not yet proven')
PY
echo '=== CANDIDATE SOURCE STATUS ==='
git status --short
echo '=== BLOCKED UNTIL ADDITIONAL TESTS ==='
echo 'No fee wallet, mining wallet or payments have been created or enabled.'
echo 'Coin template and static accounting fixture ready for further adaptation.'
