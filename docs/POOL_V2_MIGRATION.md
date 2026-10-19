# Feelcoin Pool V2 — Miningcore evaluation and migration gate

Status: **Research / not deployed** (19 October 2026).
Live pool: `pool.feelcoin.org:4242` (TLS: `4244`); existing system stays in service until proven safe.
Research base branch: `research/miningcore-feasibility-20261018`.

## Baseline
- Existing pool derives from jtgrassie's `monero-pool`. The repository documents PPLNS, a 0.5% pool fee, and a 0.33 FEEL threshold, but these are **not verified current production settings**.
- Miningcore upstream candidate: `https://github.com/oliverw/miningcore` (MIT, **archived**); evaluate supported maintained forks before selecting/pinning an immutable commit.
- Source includes Monero/RandomX code, but **Feelcoin support is unproven**. Do not mistake a successful process start for mining compatibility.
- MIT license permits changes subject to retaining copyright/license notices. The upstream README describes a built-in 0.1% development donation. The actual configured behavior must be verified in code and tests; **0.0% is a requirement, not a verified configuration**.
- Keep the existing branded dashboard if its API requirements can be mapped accurately. No misleading mock metrics.

## Strict invariants
1. No write operations to existing pool wallet RPC, database, daemon, payout ledger or public mining ports until explicit validation and cutover.
2. Preserve and reconcile pending balances, immature blocks, outstanding payouts and PPLNS share-window obligations; archive signed/exported state and transaction evidence. Do not blindly copy old share records into a new payout schema.
3. Never enable two pool payout engines against the same funds or wallet simultaneously.
4. Restrict wallet RPC to localhost/private authenticated transport. Back up and protect wallets/keys; never put secrets in Git or print them in logs.
5. Ensure FEEL amount calculations use exact atomic integer units: 12 decimal places; verify chain reward/treasury handling and payout rounding with test cases.
6. Pool fees remain 0.5% unless a separately approved change; additional developer donation must be exactly zero and tested from emitted payment records.
7. Configure PPLNS and SOLO independently; SOLO finds must credit the correct worker and must not dilute PPLNS balances.
8. Protect current `4242`/`4244` until success criteria and a rollback plan are signed off.

## Compatibility checklist — all must pass
- [ ] Pin source tree and document license, security status, build/runtime compatibility with Ubuntu 26.04.
- [ ] Map `get_block_template` and job format; block height, previous hash, seed hash, reserved offset, nonce placement and difficulty.
- [ ] Verify Feelcoin RandomX variant, seed epochs, hash verification, target conversion and endianness against daemon test vectors.
- [ ] Submit valid mined blocks, reject duplicates/invalid/expired jobs, handle reorgs/orphans and maturity correctly.
- [ ] Confirm Stratum job parsing and XMRig compatibility at each VarDiff/fixed-difficulty port.
- [ ] Validate address checksums/prefixes (standard, integrated/subaddress if applicable) and payment IDs.
- [ ] Reconcile dev treasury emission, miner rewards, transaction fees, 0.5% pool fee and 0% developer donation.
- [ ] Test PostgreSQL migrations, graceful restart, crash recovery, backup/restore, telemetry and worker accounting.
- [ ] Confirm SOLO payout isolation and block attribution.
- [ ] Test payout with a dedicated restricted test wallet and tiny controlled amounts before any production wallet access.
- [ ] Test realistic small/large miners for at least 24 hours and compare independently calculated accepted/rejected shares.
- [ ] Confirm miner balance export, immature rewards handling, and old payout settlement ledger.
- [ ] Confirm dashboard / API provenance and TLS / authorization / rate limiting.
- [ ] Have automated rollback, explicit maintenance message and documented incident procedure.

## Migration stages
A. Read-only production preflight; save *redacted* configuration and verifiable ledger snapshots.
B. Offline fork comparison and pinned source build; prove exact zero donation in payout code and automated tests.
C. Isolated staging: separate filesystem, DB, wallet and non-public Stratum ports; avoid shared payout credentials.
D. Miner and daemon integration tests; compare independently.
E. Freeze old payout engine only after accounting reconciliation; settle or explicitly carry outstanding obligations using auditable records.
F. Announce user action (only if endpoint changes) and controlled cutover with rollback.
G. Reconcile all payout transactions and monitor for regressions.

## Go / no-go criteria
GO only when *all* tests pass and outstanding balances are demonstrably protected. If upstream RandomX integration cannot match Feelcoin consensus, stop and choose a different backend; do not adapt by weakening validation. No server installation, configuration switch, production payments or publicly announced completion is implied by this document.
