#!/usr/bin/env bash
# Feelcoin Pool V2 — fetch Miningcore sources for an offline compatibility audit.
# Does not build/run Miningcore, access RPC, alter pool, or create payouts.
set -euo pipefail
umask 077
BASE="$HOME/feelcoin-pool-v2-staging"
DEST="$BASE/miningcore-source"
URL="https://github.com/oliverw/miningcore.git"
test -d "$BASE" || { echo "Missing staging directory"; exit 1; }
test ! -e "$DEST" || { echo "STOP: source checkout already exists"; exit 1; }
command -v git >/dev/null
echo '=== FETCHING RESEARCH CANDIDATE (ARCHIVED UPSTREAM) ==='
git clone --filter=blob:none --no-checkout "$URL" "$DEST"
cd "$DEST"
SHA="$(git rev-parse refs/remotes/origin/master)"
test -n "$SHA"
git checkout --detach "$SHA"
printf '%s\n' "$SHA" > "$BASE/miningcore-upstream.sha"
echo "Pinned upstream revision: $SHA"
echo '=== TECHNOLOGY ==='
find . -maxdepth 4 \( -name '*.csproj' -o -name '*Dockerfile*' \) -print | head -n 30
echo '=== RANDOMX / MONERO REFERENCE FILES ==='
git ls-files | grep -Ei 'randomx|cryptonote|monero|payment|donation' | head -n 100 || true
echo '=== DONATION IMPLEMENTATION SEARCH ==='
git grep -n -i -E 'devDonation|developer.donation|0[.]001' -- 'src/**' ':!**/coins.json' | head -n 70 || true
echo '=== FINISHED: SOURCE INSPECTION ONLY ==='
echo 'Do NOT use this archived upstream in production without Feelcoin consensus tests, dependency audit, and exact donation-path verification.'
