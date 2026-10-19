#!/usr/bin/env bash
# Single consolidated readiness audit for FEEL Pool V2. Read-only, no service changes.
set -euo pipefail
ROOT="$HOME/feelcoin-pool-v2-staging"
SRC="$ROOT/miningcore-feelcoin-candidate"
CONF="$ROOT/v2-config-drafts/miningcore-pplns-solo-disabled.json"
echo '=== FEELCOIN POOL V2 — FINAL READINESS GATE ==='
python3 - "$SRC" "$CONF" <<'PY'
import json, pathlib, sys
src=pathlib.Path(sys.argv[1]); config=pathlib.Path(sys.argv[2])
assert src.is_dir() and config.is_file()
coins=json.loads((src/'src/Miningcore/coins.json').read_text())
f=coins['feelcoin']
prefixes={'addressPrefix':84,'addressPrefixIntegrated':85,'subAddressPrefix':86,'addressPrefixTestnet':90,'addressPrefixIntegratedTestnet':91,'subAddressPrefixTestnet':92,'addressPrefixStagenet':96,'addressPrefixIntegratedStagenet':97,'subAddressPrefixStagenet':98}
assert all(f.get(k)==v for k,v in prefixes.items()), 'FEEL address mapping invalid'
assert f.get('hash')=='randomx' and f.get('smallestUnit')==10**12
cfg=json.loads(config.read_text())
assert cfg['paymentProcessing']['enabled'] is False
assert len(cfg['pools'])==2
assert {p['paymentProcessing']['payoutScheme'] for p in cfg['pools']}=={'PPLNS','SOLO'}
for p in cfg['pools']:
    assert p['enabled'] is False and p['paymentProcessing']['enabled'] is False
    assert p['paymentProcessing']['minimumPayment']==5.0
    assert p['rewardRecipients'][0]['percentage']==0.5
    assert not p['daemons']
    assert p['address'].startswith('REPLACE_WITH_')
    assert p['rewardRecipients'][0]['address'].startswith('REPLACE_WITH_')
guard=(src/'src/Miningcore/Blockchain/Cryptonote/CryptonotePayoutHandler.cs').read_text()
assert 'FEEL payout accounting blocked' in guard
assert 'blockRewardRemaining -= CryptonoteConstants.StaticTransactionFeeReserve' in guard
print('PASS: FEEL prefixes, RandomX template, 12 decimals')
print('PASS: 0.5% PPLNS/SOLO configurations and 5 FEEL thresholds')
print('PASS: no live wallet addresses, no daemon configured, payout guard active')
print('BLOCKER 1: accepted and rejected real FEEL RandomX shares not tested')
print('BLOCKER 2: dedicated wallets and secure isolated wallet RPC not configured')
print('BLOCKER 3: native FEEL network transaction fees and reward accounting not implemented')
print('BLOCKER 4: no verified migration of unpaid legacy miner balances')
print('BLOCKER 5: archived .NET 6 implementation needs supported runtime/security review')
PY
echo '=== CANDIDATE IMAGE ==='
docker image inspect feelcoin-miningcore-v2-guarded:compile-only --format 'PASS: compiled guarded image {{.Id}}'
echo '=== ISOLATED STAGING DB ==='
docker inspect feelcoin-pool-v2-postgres --format 'Container={{.Name}} Running={{.State.Running}} Health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' || true
echo '=== LIVE POOL ==='
test "$(systemctl is-active feelcoin-pool.service)" = active
echo 'PASS: original pool remains active'
echo '=== FINAL STATUS: NOT READY FOR CUTOVER ==='
echo 'No miner ports opened. No wallet or payment touched. Keep existing pool online.'
