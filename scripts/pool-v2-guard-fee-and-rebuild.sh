#!/usr/bin/env bash
# FEEL Pool V2: fail-closed transaction reserve guard + deterministic source assertions.
# Never starts services, unlocks wallet, or enables payments.
set -euo pipefail
SRC="$HOME/feelcoin-pool-v2-staging/miningcore-feelcoin-candidate"
test -d "$SRC/.git"
python3 - "$SRC" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1])
p=src/'src/Miningcore/Blockchain/Cryptonote/CryptonotePayoutHandler.cs'
s=p.read_text()
old='''        // Deduct static reserve for tx fees
        blockRewardRemaining -= CryptonoteConstants.StaticTransactionFeeReserve;

        return blockRewardRemaining;'''
new='''        // FEEL uses distinct network fee economics. Never apply a Monero-specific
        // static 0.03 XMR reserve to FEEL miner rewards. Until a dedicated FEEL
        // transaction fee model and payout accounting tests are implemented, fail
        // closed rather than distributing incorrect amounts.
        if(poolConfig.Coin.Equals("feelcoin", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("FEEL payout accounting blocked: implement and test native transaction fees first");

        // Legacy Monero reserve unchanged for non-FEEL CryptoNote coins.
        blockRewardRemaining -= CryptonoteConstants.StaticTransactionFeeReserve;

        return blockRewardRemaining;'''
if old in s:
    assert s.count(old)==1
    p.write_text(s.replace(old,new))
elif new in s:
    print('Source guard already installed.')
else:
    raise SystemExit('STOP: upstream payout logic changed; manual review required')
s=p.read_text()
assert s.count('FEEL payout accounting blocked')==1
assert s.index('FEEL payout accounting blocked') < s.index('blockRewardRemaining -= CryptonoteConstants.StaticTransactionFeeReserve;')
assert 'StringComparison.OrdinalIgnoreCase' in s
print('PASS: FEEL payout code rejects Monero static 0.03 reserve (fail-closed)')
print('PASS: non-FEEL payout reserve preserved')
PY
cd "$SRC"
git diff --check
echo '=== CHECK CHANGES ==='
git status --short
echo '=== BUILD SOURCE (NO RUN) ==='
docker build --target BUILDER --tag feelcoin-miningcore-v2-guarded:compile-only . > "$HOME/feelcoin-pool-v2-staging/feelcoin-v2-guarded-build.log" 2>&1 || {
  echo 'BUILD FAILED; last 70 lines:'
  tail -n 70 "$HOME/feelcoin-pool-v2-staging/feelcoin-v2-guarded-build.log"
  exit 1
}
echo 'PASS: compiled FEEL payout guard'
echo '=== PRODUCTION ==='
test "$(systemctl is-active feelcoin-pool.service)" = active
echo 'PASS: production active; payout functionality on V2 remains blocked'
