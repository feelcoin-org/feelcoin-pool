# Feelcoin Pool — Chain-Verified Dashboard

This directory contains the standalone Feelcoin Pool
dashboard and its read-only blockchain verification service.

## Architecture

- The mining Pool remains responsible for Stratum, shares,
  balances, block submissions and payouts.
- The dashboard reads Pool information without modifying it.
- The verifier compares recent Pool candidate hashes against
  canonical blockchain hashes.
- Alternative candidates remain distinguishable from
  verified main-chain blocks.
- Wallets, payment ledgers and LMDB are not modified.

## Operational notes

The verifier requires a reachable Feelcoin daemon RPC endpoint.
Use environment-specific configuration when deploying.

The dashboard does not replace the mining Pool backend.

## Security

Never commit production pool.conf, wallet files,
credentials, private keys, LMDB data or server backups.

## Attribution

The Feelcoin Pool is derived from jtgrassie/monero-pool.
Retain the upstream copyright notices and license.
