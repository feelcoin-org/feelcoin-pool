# Feelcoin Pool V4 — Beta Release Candidate

## Overview

Feelcoin Pool V4 builds on jtgrassie/monero-pool
with Feelcoin-specific improvements.

## Mining

- Improved block-template lifetime handling.
- Validated repeated template refreshes and Stratum jobs.
- Hardened daemon block-submission validation.
- Prevented rejected submissions from being counted
  as accepted candidates.

## Payout safety

- Durable payout-intent tracking.
- Atomic payment settlement and transaction receipts.
- Protection against automatic duplicate retries
  after ambiguous wallet responses.
- Isolated wallet failure and restart tests.

## Dashboard

- Canonical-chain verification of recent block candidates.
- Main-chain-only display by default.
- Optional visibility of alternative candidates.
- Read-only verification service.

## Testing

- Development regression suite passed.
- Production deployment and Stratum job verified.
- Successful wallet settlement observed.
- Accepted block observed after deployment.
- Dashboard classification tests passed.

## Known limitations

- Historical block records have not been fully reconciled.
- Complete historical payout reconciliation remains pending.
- The standalone dashboard requires separate deployment.
- Independent security auditing has not been completed.
- Reproducible development test fixtures still need publication.

## Attribution

Based on jtgrassie/monero-pool.
Retain upstream copyright and license notices.
