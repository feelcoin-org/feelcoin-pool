#!/usr/bin/env bash
# Replace zero-target CryptoNote encoder, rebuild and restart *isolated* V2 test.
# No changes to legacy pool, no wallet access or payouts.
set -euo pipefail
ROOT="$HOME/feelcoin-pool-v2-staging"; SRC="$ROOT/miningcore-feelcoin-candidate"
CFG="$ROOT/runtime-private/config.json"; NAME=feelcoin-pool-v2-stratum-test
IMAGE=feelcoin-miningcore-v2-targetfix:compile-only
test "$(systemctl is-active feelcoin-pool.service)" = active
test -f "$CFG" && test -d "$SRC/.git"
python3 - "$SRC" "$CFG" <<'PY'
import sys,json
from pathlib import Path
src=Path(sys.argv[1]); cfg=json.loads(Path(sys.argv[2]).read_text())
assert cfg['paymentProcessing']['enabled'] is False
assert len(cfg['pools'])==1 and cfg['pools'][0]['paymentProcessing']['enabled'] is False
assert cfg['pools'][0]['ports']['5252']['listenAddress']=='127.0.0.1'
p=src/'src/Miningcore/Blockchain/Cryptonote/CryptonoteJob.cs'
s=p.read_text()
old='''        var diff = BigInteger.ValueOf((long) (difficulty * 255d));
        var quotient = CryptonoteConstants.Diff1.Divide(diff).Multiply(BigInteger.ValueOf(255));
        var bytes = quotient.ToByteArray().AsSpan();
        Span<byte> padded = stackalloc byte[32];

        var padLength = padded.Length - bytes.Length;

        if(padLength > 0)
            bytes.CopyTo(padded.Slice(padLength, bytes.Length));

        padded = padded[..size];
        padded.Reverse();

        return padded.ToHexString();'''
new='''        if(double.IsNaN(difficulty) || double.IsInfinity(difficulty) || difficulty <= 0d ||
            difficulty > (long.MaxValue / 255d) || (size != 4 && size != 8))
            throw new ArgumentOutOfRangeException(nameof(difficulty), "Invalid CryptoNote target difficulty");

        var scaled = (long) (difficulty * 255d);
        if(scaled <= 0)
            throw new ArgumentOutOfRangeException(nameof(difficulty));

        var diff = BigInteger.ValueOf(scaled);
        var quotient = CryptonoteConstants.Diff1.Divide(diff).Multiply(BigInteger.ValueOf(255));
        var bytes = quotient.ToByteArrayUnsigned();
        if(bytes.Length > 32)
            throw new InvalidOperationException("CryptoNote target exceeds 256 bits");

        Span<byte> padded = stackalloc byte[32];
        padded.Clear();
        bytes.CopyTo(padded.Slice(32 - bytes.Length));
        var result = padded[..size];
        result.Reverse();
        if(result.IndexOfAnyExcept((byte)0) < 0)
            throw new InvalidOperationException("Encoded CryptoNote share target must not be zero");

        return result.ToHexString();'''
# IndexOfAnyExcept may not exist in .NET 6: instead use loop, fixed in construction
new=new.replace('if(result.IndexOfAnyExcept((byte)0) < 0)','if(result.ToArray().All(x => x == 0))')
if old in s:
    assert s.count(old)==1
    p.write_text(s.replace(old,new))
elif new in s: print('Patch already present')
else: raise SystemExit('STOP: unexpected job encoder source; no overwrite')
# Verify math for difficulty 100 (target expected nonzero) without using raw mine job values
u=(2**256-1)//(100*255)*255
b=u.to_bytes(32,'big')[:4][::-1]
assert b != b'\0'*4
print('PASS: 4-byte little-endian target reference for diff=100:',b.hex())
print('PASS: payouts remain disabled')
PY
cd "$SRC"; git diff --check
echo '=== COMPILE TARGET FIX ==='
docker build --target BUILDER -t "$IMAGE" . > "$ROOT/v2-targetfix-build.log" 2>&1 || {
 tail -n 55 "$ROOT/v2-targetfix-build.log"; exit 1;
}
echo 'PASS: target encoder build'
echo '=== RESTART ISOLATED TEST ONLY ==='
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" --network host --cpus 1.25 --memory 1500m \
 --security-opt no-new-privileges:true --cap-drop ALL \
 --mount "type=bind,src=$CFG,dst=/app/build/config.json,readonly" \
 --entrypoint /bin/sh "$IMAGE" \
 -c 'cd /app/build && timeout 1800 dotnet Miningcore.dll -c /app/build/config.json' >/dev/null
sleep 12
if ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
 docker logs "$NAME" --tail 40; exit 1
fi
ss -lnt | grep ':5252 ' || { docker logs "$NAME" --tail 40; exit 1; }
test "$(systemctl is-active feelcoin-pool.service)" = active
echo 'READY: targetfix staging localhost:5252 for 30 minutes; existing pool active, payouts disabled'
