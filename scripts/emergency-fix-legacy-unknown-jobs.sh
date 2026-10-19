#!/usr/bin/env bash
# Feelcoin production pool: emergency missing-job hotfix.
# Builds in an isolated git worktree. Creates binary/config backups.
# Only switches live binary after successful build, with automatic rollback.
set -Eeuo pipefail
umask 077
LIVE="$HOME/feelcoin-pool"
CORE="$HOME/feelcoin"
SERVICE="feelcoin-pool.service"
BINARY="$LIVE/build/release/feelcoin-pool"
CONF="$LIVE/pool.conf"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
ROOT="$HOME/feelcoin-recovery/emergency-jobs-$STAMP"
STAGE="$ROOT/source"
LOG="$ROOT/deploy.log"
mkdir -p "$ROOT"
exec > >(tee -a "$LOG") 2>&1
echo "=== FEELCOIN EMERGENCY JOB HISTORY HOTFIX ==="
echo "Backup: $ROOT"
sudo -v
test "$(systemctl is-active "$SERVICE")" = active
test -f "$LIVE/src/pool.c" && test -x "$BINARY" && test -f "$CONF"
test -d "$CORE/src" && git -C "$LIVE" rev-parse --is-inside-work-tree >/dev/null
PID="$(systemctl show "$SERVICE" -p MainPID --value)"
test "$PID" -gt 0
RUNNING="$(readlink -f "/proc/$PID/exe" || true)"
# Stop if production binary isn't the binary we intend to patch.
test "$RUNNING" = "$(readlink -f "$BINARY")" || { echo "STOP: active binary mismatch: $RUNNING"; exit 1; }
mkdir -p "$ROOT/backup"
cp -a "$BINARY" "$ROOT/backup/feelcoin-pool"
cp -a "$CONF" "$ROOT/backup/pool.conf"
systemctl cat "$SERVICE" > "$ROOT/backup/systemd-unit.txt"
sha256sum "$BINARY" "$CONF" > "$ROOT/backup/original-sha256.txt"
git -C "$LIVE" rev-parse HEAD > "$ROOT/backup/source-head.txt"
echo "PASS: live service, binary, config and backup verified"
git -C "$LIVE" worktree add --detach "$STAGE" HEAD
python3 - "$LIVE/src/pool.c" "$STAGE/src/pool.c" <<'PY'
from pathlib import Path
import sys,re
actual=Path(sys.argv[1]).read_text()
p=Path(sys.argv[2])
s=p.read_text()
for name,number in [('CLIENT_JOBS_MAX',4),('BLOCK_TEMPLATES_MAX',4)]:
    marker=f'#define {name} {number}'
    assert actual.count(marker)==1 and s.count(marker)==1, f'STOP: unexpected {name} definition'
    s=s.replace(marker,f'#define {name} 32')
assert s.count('#define CLIENT_JOBS_MAX 32')==1
assert s.count('#define BLOCK_TEMPLATES_MAX 32')==1
p.write_text(s)
print('PASS: job history 4 -> 32 and block templates 4 -> 32')
PY
git -C "$STAGE" diff --check
echo "=== ISOLATED BUILD (LIVE POOL STILL RUNNING) ==="
make -C "$STAGE" release MONERO_ROOT="$CORE" -j2 > "$ROOT/build.log" 2>&1 || {
  tail -n 65 "$ROOT/build.log"; echo "STOP: build failed; production untouched"; exit 1;
}
CANDIDATE="$STAGE/build/release/feelcoin-pool"
test -s "$CANDIDATE" && test -x "$CANDIDATE"
file "$CANDIDATE"
ldd "$CANDIDATE" > "$ROOT/dependencies.txt"
if grep -q 'not found' "$ROOT/dependencies.txt"; then
  cat "$ROOT/dependencies.txt"; echo "STOP: missing runtime library"; exit 1
fi
test "$(systemctl is-active "$SERVICE")" = active
echo "PASS: candidate compiled without touching live pool"
echo "=== ATOMIC INSTALL AND RESTART; ROLLBACK ON ANY ERROR ==="
BIN_DIR="$(dirname "$BINARY")"
sudo install -m 0755 "$CANDIDATE" "$BIN_DIR/.feelcoin-pool-candidate-$STAMP"
ROLLED=0
rollback() {
  if [ "$ROLLED" -eq 1 ]; then return; fi
  ROLLED=1
  echo "ROLLBACK: restoring original executable and restarting"
  sudo install -m 0755 "$ROOT/backup/feelcoin-pool" "$BIN_DIR/.feelcoin-pool-rollback-$STAMP"
  sudo mv -f "$BIN_DIR/.feelcoin-pool-rollback-$STAMP" "$BINARY"
  sudo systemctl restart "$SERVICE" || true
  sudo systemctl status "$SERVICE" --no-pager -l | tail -n 25 || true
}
trap rollback ERR INT TERM
sudo mv -f "$BIN_DIR/.feelcoin-pool-candidate-$STAMP" "$BINARY"
sudo systemctl restart "$SERVICE"
sleep 10
test "$(systemctl is-active "$SERVICE")" = active
PID2="$(systemctl show "$SERVICE" -p MainPID --value)"
test "$PID2" -gt 0
test "$(readlink -f "/proc/$PID2/exe")" = "$(readlink -f "$BINARY")"
ss -ltn | grep -Eq ':(4242|4244)[[:space:]]'
if systemctl is-failed "$SERVICE" --quiet; then echo "STOP: failed systemd unit"; exit 1; fi
trap - ERR INT TERM
echo "=== SUCCESS: PATCHED PRODUCTION POOL ACTIVE ==="
echo "Restorable executable: $ROOT/backup/feelcoin-pool"
sha256sum "$BINARY" "$ROOT/backup/feelcoin-pool"
echo "CHECK: monitor accepted/rejected shares; old session counters may reset on restart."
echo "NOTE: V2 remains isolated, payouts unchanged."
