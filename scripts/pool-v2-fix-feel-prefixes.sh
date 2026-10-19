#!/usr/bin/env bash
# Pool V2: fix all FEEL network prefixes in the isolated candidate; no runtime changes.
set -euo pipefail
SRC="$HOME/feelcoin-pool-v2-staging/miningcore-feelcoin-candidate"
DRAFT="$HOME/feelcoin-pool-v2-staging/v2-config-drafts/miningcore-pplns-solo-disabled.json"
test -d "$SRC/.git" && test -f "$DRAFT"
python3 - "$SRC" "$DRAFT" <<'PY'
from pathlib import Path
import json,sys
src=Path(sys.argv[1]); draft=Path(sys.argv[2])
p=src/'src/Miningcore/coins.json'
coins=json.loads(p.read_text())
c=coins['feelcoin']
assert c['family']=='cryptonote' and c['symbol']=='FEEL'
want={'addressPrefix':84,'addressPrefixIntegrated':85,'subAddressPrefix':86,
      'addressPrefixTestnet':90,'addressPrefixIntegratedTestnet':91,'subAddressPrefixTestnet':92,
      'addressPrefixStagenet':96,'addressPrefixIntegratedStagenet':97,'subAddressPrefixStagenet':98}
for key,val in want.items():
    old=c.get(key)
    if old is not None and old!=val and old not in (18,19,24,25,42,53,54,63,36):
        raise SystemExit(f"STOP: unexpected value in {key}: {old}")
    c[key]=val
assert c.get('smallestUnit')==1000000000000
assert c.get('hash')=='randomx'
assert c.get('hashVariant')==0
cfg=json.loads(draft.read_text())
assert cfg['paymentProcessing']['enabled'] is False
assert len(cfg['pools'])==2
for pool in cfg['pools']:
    assert pool['enabled'] is False and pool['paymentProcessing']['enabled'] is False
    assert pool['rewardRecipients']==[{'address':'REPLACE_WITH_NEW_DEDICATED_V2_FEE_ADDRESS','percentage':0.5}]
    assert pool['paymentProcessing']['minimumPayment']==5.0
    assert not pool['daemons']
# Save only if changed; do not touch monero or other coin templates.
p.write_text(json.dumps(coins,indent=4)+'\n')
verified=json.loads(p.read_text())['feelcoin']
assert all(verified[k]==v for k,v in want.items())
print('PASS: FEEL 84/85/86 mainnet, 90/91/92 testnet, 96/97/98 stagenet prefixes')
print('PASS: RandomX template, 12 decimal units, 0.5% fee, 5 FEEL threshold')
print('PASS: PPLNS and SOLO remain DISABLED; no wallets, RPC or payout enabled')
PY
echo '=== CANDIDATE SOURCE CHANGE ==='
git -C "$SRC" status --short
echo '=== EXISTING PRODUCTION ==='
test "$(systemctl is-active feelcoin-pool.service)" = active
echo 'PASS: production service running. Candidate still not deployed.'
