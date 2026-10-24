#!/usr/bin/env python3
"""Feelcoin v17 + Pool V2 SOLO/PPLNS protocol and accounting preflight.

Only checks pinned source and exercises standalone arithmetic. It does NOT
prove live RandomX shares, block acceptance, maturity or wallet payments.
"""
import importlib.util
import json
from pathlib import Path
import re
import sys

POOL = Path(__file__).resolve().parents[1]
if len(sys.argv) != 2:
    raise SystemExit("Usage: python3 tests/v17_solo_static_gate.py <pinned Core source directory>")
CORE = Path(sys.argv[1]).resolve()
version = (CORE / "src/version.cpp.in").read_text()
forks = (CORE / "src/hardforks/hardforks.cpp").read_text()
params = (CORE / "src/cryptonote_config.h").read_text()
blockchain = (CORE / "src/cryptonote_core/blockchain.cpp").read_text()
treasury = (CORE / "src/cryptonote_core/feelcoin_treasury.h").read_text()
coin = json.loads((POOL / "research/miningcore/feelcoin.coin.json").read_text())["feelcoin"]
draft_script = (POOL / "scripts/pool-v2-create-disabled-configs.sh").read_text()

assert '#define DEF_FEELCOIN_VERSION "1.0.0"' in version
mainnet = forks.split("const hardfork_t mainnet_hard_forks[]", 1)[1].split(
    "const size_t num_mainnet_hard_forks", 1)[0]
assert re.search(r"\{\s*17,\s*21205,\s*0,", mainnet), "v17 activation height mismatch"
assert re.search(r"#define HF_VERSION_FEELCOIN_LWMA\s+17\b", params)
assert re.search(r"#define DIFFICULTY_TARGET_V2\s+120\b", params)
assert "feelcoin_lwma.h" in blockchain and "HF_VERSION_FEELCOIN_LWMA" in blockchain
assert re.search(r"ACTIVATION_HEIGHT\s*=\s*590\b", treasury)
assert re.search(r"PERCENT\s*=\s*2\b", treasury)
assert re.search(r"return base_reward \* PERCENT / 100", treasury)
assert coin["hash"] == "randomx" and coin["hashVariant"] == 0
assert coin["smallestUnit"] == 10**12
assert coin["addressPrefix"] == 84

# Verify staging config intent, without creating wallets or listening sockets.
for marker in ("'feel-pplns','PPLNS',5252", "'feel-solo','SOLO',5255",
               "'enabled':False", "'percentage':0.5",
               "'minimumPayment':5.0", "'listenAddress':'127.0.0.1'"):
    assert marker in draft_script, "Missing expected staging config invariant: " + marker
assert draft_script.count("'enabled':False") >= 2
print("PASS: pinned FEEL Core v1.0 v17 height 21205 and 120-second consensus target")
print("PASS: unchanged chain treasury 2% rule activates at height 590")
print("PASS: separate 5252 PPLNS and 5255 SOLO disabled loopback-only configurations")

# Test mathematical examples only; this is NOT a production payout proof.
spec = importlib.util.spec_from_file_location(
    "reward_invariants", POOL / "scripts/pool-v2-offline-reward-invariants.py")
reward = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reward)
reward.test()

# Treasury deduction applies to subsidy, not transaction fees; fees go to miner rewards.
for base_subsidy in (1, 49, 100, 10**12, 12789012345678):
    for tx_fees in (0, 25, 10**9):
        treasury_atomic = (base_subsidy * 2) // 100
        miner_reward = base_subsidy - treasury_atomic + tx_fees
        assert miner_reward + treasury_atomic == base_subsidy + tx_fees
        pooled, pooled_fee = reward.allocate(miner_reward, {"alice": 3, "bob": 2})
        solo, solo_fee = reward.allocate(miner_reward, {"winner": 1})
        assert sum(pooled.values()) + pooled_fee == miner_reward
        assert set(solo) == {"winner"}
        assert solo["winner"] + solo_fee == miner_reward
        assert set(solo).isdisjoint(pooled)
print("PASS: v17-independent subsidy/treasury/tx-fee accounting examples")
print("PASS: PPLNS/SOLO reward totals and winner-only SOLO allocation examples")
print("BLOCKED: runtime FEEL share validation and block submission against v17 daemon")
print("BLOCKED: real pool reward/fee accounting, orphan/reorg and maturity reconciliation")
print("BLOCKED: zero developer donation must be proven in actual payout path")
print("BLOCKED: distinct secure mining/fee wallets and payout test")
print("BLOCKED: legacy unpaid miner balance migration and rollback")
print("RESULT: STATIC GATE ONLY; NOT APPROVED FOR LIVE PAYMENTS OR CUTOVER")
