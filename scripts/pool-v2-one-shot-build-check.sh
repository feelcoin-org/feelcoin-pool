#!/usr/bin/env bash
# Pool V2 one-shot offline build smoke test. NEVER launches Miningcore or accesses wallet/daemon.
set -euo pipefail
SRC="$HOME/feelcoin-pool-v2-staging/miningcore-source"
EXPECTED="a553f62301f44c6df80891e408b6526d1dd98692"
test -d "$SRC/.git" || { echo "STOP: missing archived source checkout"; exit 1; }
test "$(git -C "$SRC" rev-parse HEAD)" = "$EXPECTED" || { echo "STOP: source revision changed"; exit 1; }
test -z "$(git -C "$SRC" status --porcelain)" || { echo "STOP: source not clean"; exit 1; }
docker info >/dev/null
echo "=== PINNED SOURCE / STATIC GUARDS ==="
python3 - "$SRC" <<'PY'
import json,sys,re,pathlib
s=pathlib.Path(sys.argv[1])
coins=json.loads((s/'src/Miningcore/coins.json').read_text())
assert 'monero' in coins and 'feelcoin' not in coins, 'Unexpected coin mappings: stop'
c=(s/'src/Miningcore/Blockchain/Cryptonote/CryptonoteConstants.cs').read_text()
p=(s/'src/Miningcore/Blockchain/Cryptonote/CryptonotePayoutHandler.cs').read_text()
b=(s/'src/Miningcore/Payments/PayoutHandlerBase.cs').read_text()
assert 'StaticTransactionFeeReserve = 0.03m' in c
assert 'blockRewardRemaining -= CryptonoteConstants.StaticTransactionFeeReserve' in p
assert 'poolConfig.RewardRecipients' in b
print('PASS: expected Monero-specific payout blockers present')
print('BLOCKED: zero FEEL donation NOT yet validated')
print('BLOCKED: FEEL consensus and atomic-unit accounting NOT yet integrated')
PY
echo "=== OFFLINE ISOLATED BUILD SMOKE TEST (NO MINING, NO DB, NO RPC) ==="
# The source's build stage uses its archived .NET 6 SDK. Build is for feasibility ONLY.
# Limit Docker build concurrency to avoid competing with the live pool.
# Buildx default driver may ignore --build-arg BUILDKIT_STEP_LOG_MAX_SIZE; no port is exposed.
docker build --target BUILDER --progress=plain --tag feelcoin-miningcore-research-build:local "$SRC"
echo "=== BUILD COMPLETE; NO BACKEND DEPLOYED ==="
echo "STOP GATE: do not start this archived binary or connect wallet before FEEL adaptation, runtime upgrade and donation tests"
