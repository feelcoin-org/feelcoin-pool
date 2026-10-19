#!/usr/bin/env python3
"""FEEL treasury/reward boundary audit. Read-only daemon RPC, no wallets or DB writes."""
import json, urllib.request, decimal, subprocess, pathlib, re
from decimal import Decimal
decimal.getcontext().prec=40
URL="http://127.0.0.1:35781/json_rpc"
def rpc(method,params=None):
    payload=json.dumps({"jsonrpc":"2.0","id":"treasury-readonly","method":method,"params":params or {}}).encode()
    with urllib.request.urlopen(urllib.request.Request(URL,payload,{"Content-Type":"application/json"}),timeout=12) as f:
        obj=json.load(f)
    if obj.get('error'):raise RuntimeError(f"{method}: {obj['error']}")
    return obj.get('result') or {}
def read_amount(v):
    return str(Decimal(int(v))/Decimal(10**12))
def audit_height(height):
    h=rpc("get_block_header_by_height",{"height":height}).get("block_header") or {}
    b=rpc("get_block",{"height":height})
    blk=b.get("json")
    if isinstance(blk,str):
        blk=json.loads(blk)
    elif not isinstance(blk,dict):
        blk={}
    tx=blk.get("miner_tx") or {}
    outputs=tx.get("vout") or []
    values=[int(o.get("amount",0)) for o in outputs]
    total=sum(values)
    reward=h.get("reward")
    print(f"HEIGHT {height} | header.reward={read_amount(reward) if reward is not None else 'missing'} FEEL | miner_tx outputs={len(values)} | output_sum={read_amount(total)} FEEL")
    print("  miner_tx amounts:",[read_amount(v) for v in values][:15])
    if reward is not None:
        print("  header.reward minus miner_tx sum:",read_amount(int(reward)-total),"FEEL")
    print("  NOTE: stealth output recipients cannot be classified as treasury/miners from amounts alone")
def main():
    info=rpc("get_info")
    height=int(info.get("height",0))
    print("=== FEEL TREASURY BLOCK REWARD AUDIT (READ ONLY) ===")
    print("Network daemon height:",height,"nettype:",info.get("nettype","unknown"))
    if height<15: raise SystemExit("STOP: insufficient blocks")
    for h in sorted(set([height-11,height-21,height-41])):
        try:audit_height(h)
        except Exception as exc: print("HEIGHT",h,"RPC inspection failed:",type(exc).__name__,str(exc)[:200])
    print("=== LOCAL SOURCE SEARCH (SNIPPETS ONLY) ===")
    base=pathlib.Path.home()
    candidates=[base/"feelcoin",base/"feelcoin-core",base/"feelcoin-github-sync",base/"feelcoin-daemon",base/"feelcoin-source"]
    for root in candidates:
        if not root.is_dir():continue
        print("SOURCE",root)
        try:
            r=subprocess.run(["rg","-n","-i","-m","3","treasury|governance.reward|dev.fund|fee.address|reward.*percent|percent.*reward",str(root/"src")],capture_output=True,text=True,timeout=10)
            # Limit to 18 lines; paths and public constants only, no config secrets
            for line in r.stdout.splitlines()[:18]:
                if any(s in line.lower() for s in ["secret","private_key","seed","password"]):continue
                print(" ",line[:240])
        except (OSError,subprocess.TimeoutExpired):pass
    print("=== INTERPRETATION ===")
    print("Do not assume header.reward is total emission or miner-only reward without consensus source verification.")
    print("Do not deduct treasury again in Miningcore if consensus already allocates it.")
    print("Payout processing must remain disabled until reward recipient accounting is verified.")
if __name__=="__main__":main()
