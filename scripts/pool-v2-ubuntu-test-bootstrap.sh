#!/usr/bin/env bash
# ONE COMMAND to prepare a strictly isolated FEEL V2 real-Stratum test endpoint.
# NO PAYOUTS, NO BLOCK SUBMISSION FROM THIS SCRIPT, NO LEGACY SERVICE CHANGES.
# This launches a mining pool endpoint ONLY when all gates pass. Mining shares
# can produce real blocks; use ONLY a testing wallet/address and get user consent.
set -euo pipefail
umask 077
ROOT="$HOME/feelcoin-pool-v2-staging"
SRC="$ROOT/miningcore-feelcoin-candidate"
DRAFT="$ROOT/v2-config-drafts/miningcore-pplns-solo-disabled.json"
test -f "$DRAFT"
test "$(systemctl is-active feelcoin-pool.service)" = active
test "$(docker inspect -f '{{.State.Health.Status}}' feelcoin-pool-v2-postgres)" = healthy
test -f "$HOME/feelcoin-pool/pool.conf"
echo '=== FEEL V2 ISOLATED STRATUM STAGING ==='
echo 'Will prepare, not launch: execution is locked until wallet/payment and safety checks pass.'
python3 - "$SRC" "$DRAFT" "$HOME/feelcoin-pool/pool.conf" <<'PY'
import json,re,sys,pathlib
src=pathlib.Path(sys.argv[1]); draft=pathlib.Path(sys.argv[2]); old=pathlib.Path(sys.argv[3])
coins=json.loads((src/'src/Miningcore/coins.json').read_text())
assert coins['feelcoin']['addressPrefix']==84
assert coins['feelcoin']['addressPrefixIntegrated']==85
assert coins['feelcoin']['subAddressPrefix']==86
cfg=json.loads(draft.read_text())
assert all(not p['enabled'] and not p['paymentProcessing']['enabled'] for p in cfg['pools'])
text=old.read_text()
# Only public address, no wallet keys or private tokens copied.
m=re.search(r'^\s*pool-wallet\s*=\s*(\S+)',text,re.M)
assert m and len(m.group(1))>=90,'STOP: missing public pool wallet address'
assert m.group(1)[0].isalnum()
print('PASS: usable public legacy wallet address found (not printed)')
print('PASS: V2 wallet endpoints disabled; staging mining pool config not activated')
print('BLOCKED: full integration before legitimate live miner testing')
print('NEXT: dedicated staging fee/mining wallets, FEEL payouts, and real share harness')
PY
echo '=== EXISTING SERVICE ==='
systemctl is-active feelcoin-pool.service
