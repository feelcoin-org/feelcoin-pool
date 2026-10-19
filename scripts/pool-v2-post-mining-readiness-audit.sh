#!/usr/bin/env bash
# FEEL Pool V2: post-Stratum integration readiness audit. Strictly read-only.
set -euo pipefail
ROOT="$HOME/feelcoin-pool-v2-staging"
SRC="$ROOT/miningcore-feelcoin-candidate"
CFG="$ROOT/runtime-private/config.json"
DRAFT="$ROOT/v2-config-drafts/miningcore-pplns-solo-disabled.json"
echo '=== FEELCOIN POOL V2: POST-MINING READINESS AUDIT ==='
python3 - "$SRC" "$CFG" "$DRAFT" <<'PY'
from pathlib import Path
import sys,json,re
src,conf,draft=map(Path,sys.argv[1:])
assert src.is_dir() and conf.is_file() and draft.is_file(), 'missing staged source/config'
p=src/'src/Miningcore/Blockchain/Cryptonote/CryptonotePayoutHandler.cs'
job=src/'src/Miningcore/Blockchain/Cryptonote/CryptonoteJob.cs'
assert p.is_file() and job.is_file()
pay=p.read_text(); j=job.read_text()
assert 'FEEL payout accounting blocked' in pay, 'CRITICAL: FEEL-specific payout guard absent'
assert 'StaticTransactionFeeReserve' in pay, 'unexpected fee accounting source; needs independent review'
assert 'Encoded CryptoNote share target must not be zero' in j, 'target zero guard missing'
cfg=json.loads(conf.read_text()); d=json.loads(draft.read_text())
assert cfg['paymentProcessing']['enabled'] is False, 'CRITICAL: cluster payout enabled'
assert len(cfg['pools']) == 1
for pool in cfg['pools']:
 assert pool['paymentProcessing']['enabled'] is False, 'CRITICAL: live test payout enabled'
 assert pool['ports']['5252']['listenAddress'] == '127.0.0.1', 'CRITICAL: test port public'
 assert float(pool['ports']['5252']['difficulty']) >= 100, 'unexpected low initial diff'
assert d['paymentProcessing']['enabled'] is False
assert {p['paymentProcessing']['payoutScheme'] for p in d['pools']} == {'PPLNS','SOLO'}
assert all(p['enabled'] is False and p['paymentProcessing']['enabled'] is False for p in d['pools'])
assert all(p['paymentProcessing']['minimumPayment'] == 5 for p in d['pools'])
assert all(len(p['rewardRecipients'])==1 and p['rewardRecipients'][0]['percentage']==0.5 for p in d['pools'])
print('PASS: RandomX target zero protection present')
print('PASS: payout processing disabled in live test and PPLNS/SOLO draft')
print('PASS: staging Stratum bound to 127.0.0.1:5252')
print('PASS: draft PPLNS + SOLO, 0.5% pool fee each, 5 FEEL minimum')
print('IMPORTANT: miner accepted shares (reported externally), but server-side accounting not yet independently audited')
print('BLOCKER: FEEL native tx fee reserve/accounting must be implemented/tested')
print('BLOCKER: dry-run block candidate, maturity, orphan and PPLNS/SOLO credit tests')
print('BLOCKER: wallet RPC isolation and payout transactions test with disposable funds')
print('BLOCKER: verified snapshot/reconciliation of legacy unpaid miner balances')
print('BLOCKER: supported .NET runtime/security and backup/rollback validation')
PY
echo '=== STAGING CONTAINERS ==='
for c in feelcoin-pool-v2-stratum-test feelcoin-pool-v2-postgres; do
 docker inspect "$c" --format '{{.Name}} state={{.State.Status}} exit={{.State.ExitCode}}' 2>/dev/null || echo "$c: not present"
done
echo '=== PRODUCTION (READ ONLY) ==='
systemctl is-active feelcoin-pool.service
echo 'RESULT: STAGING TEST SUCCESS DOES NOT AUTHORIZE CUTOVER'
