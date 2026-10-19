# Feelcoin Pool V2 — Miningcore audit findings (2026-10-19)

Upstream evaluated: oliverw/miningcore a553f62301f44c6df80891e408b6526d1dd98692 (archived, MIT). No build or miner/payout integration verified.

## Confirmed blockers
1. Miningcore.csproj targets net6.0, an unsupported runtime. A maintained supported runtime/build is necessary.
2. coins.json contains Monero but no Feelcoin template. Existing Feelcoin pool.c declares mainnet address prefix 84 and testnet 90; validate against consensus sources.
3. CryptonoteConstants.StaticTransactionFeeReserve = 0.03m, and CryptonotePayoutHandler.UpdateBlockRewardBalancesAsync subtracts this amount from block rewards. Replace Monero-specific policy after FEEL wallet fee testing.
4. PayoutHandlerBase.UpdateBlockRewardBalancesAsync credits reward recipients configured at positive percentages. Explicitly audit recipient configuration, donation behavior and actual payout accounting; searching for donation keywords is insufficient.
5. CryptonoteConstants includes 60 production payout confirmations, nonce offset 39 and reserved size 9; test against Feelcoin authoritative block fixtures.
6. PPLNS and SOLO algorithms are present, but pool isolation, accounting correctness and credit assignment have not been tested.
7. FEEL uses 12 decimal places; verify conversions, rounding, miner fee, consensus treasury and wallet transfer units against exact atomic values.
8. Native RandomX, CryptoNote RPC formats and authentication require compatibility and security validation. Never share production wallet access with staging.

## Gated next steps
A. Compare supported upstream/fork options and pin exact source.
B. Build deterministic FEEL consensus and RPC fixtures.
C. Adapt coin template, fee logic, 0%-donation checks, block jobs and wallet formats in a nonproduction branch.
D. Build and test with staging only, payments disabled, without changing mining endpoints.
E. Reconcile historical miner liabilities prior to cutover.

Status: source audit only; production pool unchanged. Staging PostgreSQL has been confirmed healthy by Node1 operator.