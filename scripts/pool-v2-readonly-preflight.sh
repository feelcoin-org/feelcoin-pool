#!/usr/bin/env bash
# Feelcoin Pool V2 — non-destructive preflight. Reads metadata only.
# Does not restart services, read wallet data, or send payout requests.
set -euo pipefail
export LC_ALL=C
echo '=== FEELCOIN POOL V2: READ-ONLY PREFLIGHT ==='
date -u '+UTC: %Y-%m-%d %H:%M:%S'
uname -sm
echo '=== RESOURCES ==='
free -h | head -n 2
df -h / | tail -n 1
echo '=== REQUIRED TOOLS ==='
for t in git make cmake gcc dotnet docker psql python3; do
  if command -v "$t" >/dev/null 2>&1; then
    printf '%s: available\n' "$t"
  else
    printf '%s: missing\n' "$t"
  fi
done
echo '=== PRODUCTION SERVICE (metadata only) ==='
if command -v systemctl >/dev/null 2>&1; then
  systemctl show feelcoin-pool.service \
    -p LoadState -p ActiveState -p SubState -p MainPID \
    -p WorkingDirectory --no-pager || true
fi
echo '=== TCP LISTENING PORTS (no process credentials) ==='
python3 - <<'PY'
from pathlib import Path
target = {4242,4243,4244,35781,35784,5432,6379}
found = set()
for filename in ('/proc/net/tcp','/proc/net/tcp6'):
    p = Path(filename)
    if not p.exists():
        continue
    for line in p.read_text().splitlines()[1:]:
        fields = line.split()
        if len(fields) > 3 and fields[3] == '0A':
            port = int(fields[1].split(':')[-1],16)
            if port in target:
                found.add(port)
for port in sorted(target):
    print(f'{port}: ' + ('LISTEN' if port in found else 'not listening in this namespace'))
PY
echo '=== CONFIGURATION KEYS (values deliberately withheld) ==='
config="${HOME}/feelcoin-pool/pool.conf"
if [[ -f "$config" ]]; then
  grep -E '^[[:space:]]*(pool-port|pool-ssl-port|webui-port|rpc-port|wallet-rpc-port|payment-threshold|pool-fee|disable-payouts)[[:space:]]*=' "$config" | cut -d= -f1 | sed -E 's/[[:space:]]*$//; s/$/ = [REDACTED]/' || true
else
  echo 'No configuration at expected local path'
fi
echo '=== COMPLETED READ-ONLY: no wallets, private keys, balances, or password values accessed ==='
