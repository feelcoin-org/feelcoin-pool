#!/usr/bin/env python3
"""FEEL treasury: read-only verify coinbase output split with exact atomic amounts."""
import urllib.request,json
from decimal import Decimal
U="http://127.0.0.1:35781/json_rpc"
def rpc(method,params):
    req=urllib.request.Request(U, json.dumps({"jsonrpc":"2.0","id":"audit","method":method,"params":params}).encode(),{"Content-Type":"application/json"})
    with urllib.request.urlopen(req,timeout=10) as r: obj=json.load(r)
    if obj.get("error"):raise ValueError(obj["error"])
    return obj["result"]
for height in [13187,13207,13217]:
    r=rpc("get_block",{"height":height}); h=r["block_header"]; blk=json.loads(r["json"])
    amounts=[int(x["amount"]) for x in blk["miner_tx"]["vout"]]
    total=sum(amounts); smaller=min(amounts); miner=max(amounts)
    assert len(amounts)==2 and total==int(h["reward"])
    print(f"height={height} total={Decimal(total)/10**12} FEEL")
    print(f" outputs={amounts}; smaller treasury candidate = {Decimal(smaller)/Decimal(total)*100:.8f}%")
    print(f" miner candidate={Decimal(miner)/10**12}, fee 0.5% floor={miner//200} atomic, miner after fee={miner-miner//200} atomic")
    assert abs(Decimal(smaller)/Decimal(total)-Decimal("0.02"))<Decimal("0.0001")
print("PASS: outputs precisely sum to header reward, ~2% small output across inspected blocks.")
print("UNVERIFIED: small output's recipient and exact consensus rule must be checked in source; payout engine remains disabled.")
