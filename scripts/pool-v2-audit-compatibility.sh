#!/usr/bin/env bash
# Pool V2 focused compatibility audit; read-only source inspection, no secrets.
set -euo pipefail
SRC="$HOME/feelcoin-pool-v2-staging/miningcore-source"
test -d "$SRC/.git" || { echo 'Missing source checkout'; exit 1; }
cd "$SRC"
echo '=== REPRODUCIBILITY ==='
git rev-parse HEAD
git status --short
echo '=== SDK TARGET ==='
grep -nE '<TargetFramework|<TargetFrameworks|<PackageReference' src/Miningcore/Miningcore.csproj | head -n 35 || true
echo '=== DONATION DEFINITIONS AND CALL SITES (source only) ==='
git grep -niE 'donat|devfee|dev.fee|coinfoundry|oliverw' -- 'src/Miningcore/*.cs' 'src/Miningcore/**/*.cs' 'src/Miningcore/**/*.json' | head -n 110 || true
echo '=== CRYPTONOTE CONSTANTS ==='
sed -n '1,210p' src/Miningcore/Blockchain/Cryptonote/CryptonoteConstants.cs
echo '=== CRYPTONOTE COIN CONFIG REFERENCES ==='
python3 - <<'PY'
import json
p='src/Miningcore/coins.json'
coins=json.load(open(p))
for name,v in coins.items():
    if v.get('family','').lower() in ('cryptonote','monero') or name in ('monero','feelcoin'):
        print(name, {k:v.get(k) for k in ('family','symbol','coinUnits','coinbaseHasher','headerHasher','blockHasher','addressPrefix') if k in v})
PY
echo '=== CONSENSUS, VALIDATION, PAYOUT TOUCHPOINTS ==='
git grep -nE 'CoinUnits|coinUnits|addressPrefix|AddressPrefix|RandomX|randomX|BlockTemplate|blockReward|BlockReward|PaymentProcessing|devDonation|DevDonation' -- 'src/Miningcore/Blockchain/Cryptonote/*.cs' 'src/Miningcore/Blockchain/Cryptonote/**/*.cs' 'src/Miningcore/Payments/*.cs' 'src/Miningcore/Payments/**/*.cs' | head -n 175 || true
echo '=== VERIFIED ONLY SOURCE INSPECTION; NO MINING OR PAYOUTS STARTED ==='
