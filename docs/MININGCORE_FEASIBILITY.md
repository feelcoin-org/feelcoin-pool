# Miningcore replacement feasibility — 18 October 2026

**Status:** Research / non-production. **Do not merge or deploy as a replacement yet.**

## Purpose

Evaluate the actively developed `NINJAK1DD/miningcore` fork as a **parallel,
isolated** replacement candidate for the Feelcoin pool. Nothing in this
branch changes a running service, port, database, wallet, payout, or firewall.

Sources pinned for review:
- Candidate: https://github.com/NINJAK1DD/miningcore/tree/89f7070c1ca0e3965d9c5a2e07fa42caf65f5e70
- CryptoNote job manager: `src/Miningcore/Blockchain/Cryptonote/CryptonoteJobManager.cs`
- CryptoNote payout handler: `src/Miningcore/Blockchain/Cryptonote/CryptonotePayoutHandler.cs`
- Miner worker job: `src/Miningcore/Blockchain/Cryptonote/CryptonoteJob.cs`
- SOLO credit accounting: `src/Miningcore/Payments/PaymentSchemes/SOLOPaymentScheme.cs`
- Example of difficulty ports: `examples/monero_pool.json`
- Feelcoin consensus: https://github.com/feelcoin-org/feelcoin

## Findings

1. Miningcore has a configurable multi-port Stratum implementation: its Monero
   example sets independent starting difficulties and VarDiff ranges for low,
   medium and high ports. This is promising but not proof of Feelcoin readiness.
2. Miningcore contains RandomX hashing support and CryptoNote daemon template,
   share validation, and payout code. Feelcoin must be registered as a
   **separate CryptoNote coin**; substituting `monero` is not sufficient.
3. Miningcore has a SOLO *pool payout scheme*: it credits the confirmed
   block reward to the block-finding miner in the pool's accounting and
   later pays out from a custodial pool wallet. This is **not** direct
   coinbase-to-miner SOLO. Two modes must never be described as equivalent.
4. Feelcoin block subsidy changes from height 590: 98% to miner/pool,
   2% to protocol treasury, and transaction fees remain 100% miner/pool.
   Miningcore's generic CryptoNote reward processing may treat aggregate
   block header reward as miner-payable. Verify on-chain decoded outputs
   and adjust accounting *before* any payment functionality is enabled.
5. Feelcoin uses 12 atomic decimals, network-specific address prefixes,
   ~120-second block target, and a RandomX seed. All require chain-specific
   compatibility and boundary tests.
6. Existing Feelcoin production pool already has durable payout-intent and
   block-submission safeguards. A replacement must meet or improve those
   guarantees. GitHub `main` is not necessarily the live binary; compare
   against the live deployed source and outstanding
   `fix/stable-pool-difficulty-hashrate-20261018` branch before any cutover.
7. Local SOLO already exists in the official Feelcoin miner. This evaluation
   is about **remote Stratum SOLO**, not that existing local-daemon mode.

## Intended endpoints (PROPOSED ONLY)

| Port | Mode | Status |
| --- | --- | --- |
| 4242 | Existing PPLNS / legacy entry | Preserve, no migration by default |
| 4244 | Existing TLS | Preserve, confirm actual runtime |
| 4245 | PPLNS lower starting difficulty + VarDiff | Not deployed |
| 4246 | PPLNS medium starting difficulty + VarDiff | Not deployed |
| 4247 | PPLNS higher starting difficulty + VarDiff | Not deployed |
| 4250 | SOLO, regular share difficulty | Not deployed |
| 4251 | SOLO, higher share difficulty | Not deployed |

Starting share difficulty must be calibrated with real hashrate and accepted/
rejected-share measurements. It is **not** network difficulty or block
difficulty, and raising it does not increase a miner's probability of
finding a block. For solo Stratum, the winning miner must receive only
the reward permitted by Feelcoin consensus. Official SOLO policy: **0%
pool fee**, with the 2% protocol treasury still applicable.

## Non-negotiable implementation gates

- [ ] **Proof of compatibility:** compare address-prefix and network-type
      validation, parsing and hashing of `get_block_template` data, seed
      rotation, RandomX results, and 120-second target with the current
      Feelcoin daemon using fixed fixture vectors.
- [ ] **Proof of coinbase accounting:** verify subsidy, fees and treasury
      outputs before/after block 590; reconcile both RPC rewards and miner
      reward with decoded consensus outputs. 98/2 split is from subsidy,
      *not* transaction fees.
- [ ] **Proof of reward ownership:** specify and test separately (a)
      PPLNS and (b) true direct-coinbase SOLO, or clearly label any interim
      custodial SOLO implementation. Zero pooled-share pollution.
- [ ] **No wallet exposure:** daemon RPC and wallet RPC remain loopback
      only, wallet credentials/seeds never enter PRs/logs or public API.
- [ ] **Test payout integrity:** check idempotent transfer retries, durable
      intent/receipt state, double-payout prevention, chain reorg handling,
      block maturity and orphan detection. Do not enable payouts before
      reconciliation against a shadow ledger.
- [ ] **Capacity and reliability:** test low/medium/high VarDiff ports,
      malformed shares, invalid nonce/duplicate/stale jobs, reconnect,
      block-template freshness, low hash rate and NiceHash/proxy miners.
- [ ] **Read-only shadow:** stage on a different host/network namespace,
      no production wallet, no miner traffic, no shared LMDB/PostgreSQL
      data. Do **not** bind any advertised mining port.
- [ ] **Dry-run load test:** replay synthetic shares (not paid), compare
      with production software, validate stats endpoint and stability.
- [ ] **Cutover accounting:** freeze and export old balances/payments,
      compare independent ledger totals, record last block height and
      pending payout intents, preserve immutable backups, obtain rollback
      runbook; only then migrate miners gradually.
- [ ] **Rollback:** tested binary/config + persistent database snapshots
      and monitored return to port 4242 within explicit recovery bounds.
- [ ] **Verification:** compile, run unit/integration tests, and execute a
      controlled real-chain block acceptance test with non-production
      wallet and appropriate consensus safety precautions.

## Read-only first probe

On a machine that hosts a locally synchronized Feelcoin daemon, run:

```bash
python3 tools/feelcoin_miningcore_probe.py --pool-conf ./pool.conf
```

The probe sends **only** `get_info`, `get_last_block_header`, and
`get_block_template` via the local daemon RPC. It makes no wallet,
transfer, submission, filesystem-write or service-management calls.
It does **not** prove Miningcore compatibility or real block accounting.
No script in this evaluation should be run blindly on production.

## Decision

**Research candidate, not approved for replacement.** Evaluate the
maintained Miningcore fork beside the existing Feelcoin pool, but
preserve production `4242` and `4244`. Do not deploy/merge simply
because a check passes; payout and reward correctness are the gate.
