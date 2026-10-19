#!/usr/bin/env bash
# Create offline PPLNS and SOLO staging configs only. Does not start services or touch wallets.
set -euo pipefail
umask 077
ROOT="$HOME/feelcoin-pool-v2-staging"
SRC="$ROOT/miningcore-feelcoin-candidate"
test -d "$SRC/.git" && test -f "$SRC/src/Miningcore/coins.json"
python3 - "$ROOT" "$SRC" <<'PY'
from pathlib import Path
import json,sys,decimal
root=Path(sys.argv[1]); src=Path(sys.argv[2])
coin=json.loads((src/'src/Miningcore/coins.json').read_text())['feelcoin']
assert coin['symbol']=='FEEL' and coin['addressPrefix']==84
# Config is an explicit template: no real pool or fee address, no RPC secrets, all mining DISABLED.
d=root/'v2-config-drafts'; d.mkdir(exist_ok=True)
out=d/'miningcore-pplns-solo-disabled.json'
if out.exists():
    raise SystemExit('STOP: existing draft untouched')
configs=[]
for name,scheme,port in [('feel-pplns','PPLNS',5252),('feel-solo','SOLO',5255)]:
    config={
      'id':name,'enabled':False,'coin':'feelcoin','address':'REPLACE_WITH_NEW_DEDICATED_V2_POOL_ADDRESS',
      'rewardRecipients':[{'address':'REPLACE_WITH_NEW_DEDICATED_V2_FEE_ADDRESS','percentage':0.5}],
      'ports':{str(port):{'listenAddress':'127.0.0.1','difficulty':1000 if scheme=='PPLNS' else 10000,
                         'name':scheme,'varDiff':{'minDiff':100,'maxDiff':None,'targetTime':30,'retargetTime':90,'variancePercent':30}}},
      'daemons':[],
      'paymentProcessing':{'enabled':False,'minimumPayment':5.0,'payoutScheme':scheme}
    }
    if scheme=='PPLNS': config['paymentProcessing']['payoutSchemeConfig']={'factor':2.0}
    configs.append(config)
cfg={'logging':{'level':'info','enableConsoleLog':True},
     'persistence':{'postgres':{'host':'REPLACE_WITH_ISOLATED_DB_SERVICE','port':5432,'user':'feelcoin_pool_v2','password':'REPLACE_WITH_SECRET_FROM_LOCAL_DOTENV','database':'feelcoin_pool_v2'}},
     'paymentProcessing':{'enabled':False},
     'pools':configs}
assert all(not p['enabled'] and not p['paymentProcessing']['enabled'] for p in configs)
assert all(p['rewardRecipients'][0]['percentage']==0.5 for p in configs)
assert all(p['paymentProcessing']['minimumPayment']==5 for p in configs)
out.write_text(json.dumps(cfg,indent=2)+'\n')
out.chmod(0o600)
print('PASS: disabled PPLNS + SOLO draft configs created')
print('PASS: 0.5% fee recipient planned, 5 FEEL payout threshold')
print('PASS: independent pool IDs, local-only mining ports, no wallet RPC configured')
print('BLOCKED: actual FEEL mining, fee wallets, RandomX mining test, confirmed donation removal and payouts')
print('Draft:',out)
PY
echo '=== EXISTING PRODUCTION SERVICE ==='
systemctl is-active feelcoin-pool.service
echo '=== NO NEW POOL STARTED ==='
