# Feelcoin Pool V2 — wallets, fees and payout policy

Status: proposed configuration pending explicit confirmation and integration tests. NO wallet created, NO payment code or production settings changed.

## Wallet segregation
- Create a new dedicated mining reward wallet for Pool V2 (address and view key must not be published with secrets). Keep spend credentials offline/restricted, and minimize hot-wallet funds.
- Create a different dedicated fee-receiving wallet. Never substitute the consensus-level 2% treasury address for this operational fee wallet.
- Maintain independent balances, labels, access permissions, backups and audit trails. Prefer an internal fee allocation ledger followed by verifiable transfers, if supported by tested backend behavior.
- Never put seeds, private spend keys, wallet passwords or RPC credentials in Git or build logs.
- Do not mix historic PPLNS miner liabilities with new Pool V2 wallet funds; reconcile and settle old balances separately, record outstanding immature blocks.

## Proposed economics
- PPLNS fee: 1% (proposed; old pool remains 0.5% until explicitly communicated cutover).
- SOLO fee: 1% proposed; fee handling must be tested separately.
- Minimum payout: 1 FEEL proposed; confirm network fees, atomic rounding, and miner earnings before finalizing.
- Additional Miningcore developer deduction: 0% required; prove with payout-path audit and tests.
- Feelcoin protocol treasury: separate consensus-level allocation, not pool fee.
- Payout engine DISABLED until actual reward, maturity, security, reconciliations and atomic-unit tests pass.
- Publish fee and threshold policy to miners ahead of any changes; do not change historical reward obligations retrospectively.

## Acceptance tests
- Distinct wallet addresses verified from locally generated, backed-up wallets; never post secrets.
- Reward credited to designated pool wallet; fee to designated fee wallet, miner rewards reconcile in atomic units (12 decimals).
- PPLNS and SOLO accounting separately validated, with independent reward ownership.
- Edge cases: orphan/reorg, reserve/transaction fee, payout threshold, tiny rewards, miner address validation, retries, duplicate payout prevention.
- Ledger reports reconcile inputs/outputs and legacy unpaid amounts; production cutover only with explicit approvals.
