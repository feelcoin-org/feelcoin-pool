#!/usr/bin/env bash
# Feelcoin V2 one-pass protocol fixture capture: READ-ONLY daemon RPC.
# Never submits blocks, sends transfers, accesses wallet RPC, or changes services.
set -euo pipefail
export LC_ALL=C
ROOT="$HOME/feelcoin-pool-v2-staging"
CAND="$ROOT/miningcore-feelcoin-candidate"
CONF="$HOME/feelcoin-pool/pool.conf"
test -f "$CAND/src/Miningcore/coins.json"
test -f "$CONF"
python3 - "$CONF" "$CAND" <<'PY'
import sys, re, json, urllib.request, hashlib
from pathlib import Path
conf=Path(sys.argv[1]).read_text().splitlines()
values={}
for line in conf:
    m=re.match(r'^\s*([a-z][a-z-]*)\s*=\s*(.*?)\s*$',line)
    if m: values[m.group(1)]=m.group(2)
host=values.get("rpc-host")
port=values.get("rpc-port")
address=values.get("pool-wallet","")
assert host in ("127.0.0.1","localhost","::1"), "STOP: RPC not restricted to localhost"
assert port and port.isdecimal() and 1<=int(port)<=65535
assert address and len(address)<130 and not any(x.isspace() for x in address), "STOP: missing/invalid configured public pool address"
coins=json.loads((Path(sys.argv[2])/"src/Miningcore/coins.json").read_text())
feel=coins["feelcoin"]
assert feel["family"]=="cryptonote" and feel["addressPrefix"]==84
def call(method,params=None):
    body=json.dumps({"jsonrpc":"2.0","id":"feel-v2-probe","method":method,"params":params or {}}).encode()
    req=urllib.request.Request(f"http://127.0.0.1:{port}/json_rpc",body,{"Content-Type":"application/json"})
    with urllib.request.urlopen(req,timeout=12) as response:
        result=json.load(response)
    if "error" in result: raise RuntimeError(f"{method} RPC error: {result['error'].get('code')}")
    assert isinstance(result.get("result"),dict),f"{method}: missing result"
    return result["result"]
info=call("get_info")
print("=== READ-ONLY FEEL BLOCK TEMPLATE FIXTURE ===")
print("network_height:",info.get("height","N/A"))
print("network_difficulty:",info.get("difficulty","N/A"))
result=call("getblocktemplate",{"wallet_address":address,"reserve_size":9})
for key in ("height","difficulty","reserved_offset","seed_hash","prev_hash","expected_reward","wide_difficulty","status"):
    if key in result:
        val=result[key]
        if key in ("seed_hash","prev_hash") and isinstance(val,str): val=f"{val[:12]}... (redacted)"
        print(f"{key}: {val}")
blob=result.get("blocktemplate_blob","")
hashing_blob=result.get("blockhashing_blob","")
assert blob and len(blob)%2==0 and all(c in "0123456789abcdefABCDEF" for c in blob)
assert hashing_blob and len(hashing_blob)%2==0 and all(c in "0123456789abcdefABCDEF" for c in hashing_blob)
offset=result.get("reserved_offset",result.get("reservedOffset"))
assert isinstance(offset,int) and 0<=offset and offset+9<=len(blob)//2,"STOP: invalid reserved offset"
assert isinstance(result.get("height"),int) and isinstance(result.get("difficulty"),int)
print("template_bytes:",len(blob)//2)
print("hashing_blob_bytes:",len(hashing_blob)//2)
print("template_sha256:",hashlib.sha256(bytes.fromhex(blob)).hexdigest())
print("hashing_blob_sha256:",hashlib.sha256(bytes.fromhex(hashing_blob)).hexdigest())
print("template_validated: true")
print("=== NO MINING, BLOCK SUBMISSION, WALLET RPC OR PAYOUTS ===")
PY
