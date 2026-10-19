#!/usr/bin/env python3
"""Feelcoin Pool V2 offline payout arithmetic tests, no wallet/daemon/network.
Not a substitute for native wallet RPC integration tests.
"""
from decimal import Decimal, getcontext
getcontext().prec = 45
ATOMIC = Decimal(10)**12
FEE = Decimal("0.005")
MINIMUM = Decimal("5")

def atomic(feel):
    raw = Decimal(str(feel))*ATOMIC
    assert raw == raw.to_integral_exact(), "fractional atomic amount"
    return int(raw)

def allocate(reward_atomic, weights, fee=FEE):
    assert isinstance(reward_atomic,int) and reward_atomic >= 0
    assert weights and all(isinstance(v,int) and v>=0 for v in weights.values())
    assert sum(weights.values())>0
    assert Decimal('0')<=fee<Decimal('1')
    fee_atomic=int(Decimal(reward_atomic)*fee)  # round down, no fractional atoms
    distributable=reward_atomic-fee_atomic
    total=sum(weights.values())
    miner={k:distributable*v//total for k,v in weights.items()}
    remainder=distributable-sum(miner.values())
    # Deterministic largest-remainder assignment, no lost atoms
    order=sorted(weights,key=lambda k:(-(distributable*weights[k]%total),k))
    for k in order[:remainder]: miner[k]+=1
    assert sum(miner.values())+fee_atomic==reward_atomic
    return miner,fee_atomic

def test():
    # PPLNS window share weighting
    shares={'miner-a':7,'miner-b':3}
    miners,fee=allocate(atomic("12.345678901234"),shares)
    assert fee==atomic("0.061728394506")
    assert sum(miners.values())+fee==atomic("12.345678901234")
    assert miners['miner-a']>miners['miner-b']
    # SOLO: full reward less pool fee to winning miner, never split by hashrate
    solo,solo_fee=allocate(atomic("3"),{'winning-miner':1})
    assert solo['winning-miner']==atomic("2.985")
    assert solo_fee==atomic("0.015")
    # maturity/orphans: neither pending nor orphan credits spendable
    blocks=[
        {'status':'pending','reward':atomic("10"),'weights':{'miner-a':1}},
        {'status':'orphaned','reward':atomic("10"),'weights':{'miner-b':1}},
        {'status':'confirmed','reward':atomic("6"),'weights':{'miner-c':1}},
    ]
    credits={}
    for b in blocks:
        if b['status']!='confirmed': continue
        alloc,_=allocate(b['reward'],b['weights'])
        for addr,amount in alloc.items(): credits[addr]=credits.get(addr,0)+amount
    assert credits=={'miner-c':atomic("5.97")}
    assert credits['miner-c']>=atomic(MINIMUM)
    assert atomic('4.999999999999')<atomic(MINIMUM)
    # invariant across awkward atom counts and different PPLNS allocations
    for r in [1,2,3,10,100,atomic('0.3'),atomic('5'),atomic('100')]:
        for w in [{'a':1},{'a':2,'b':3},{'a':1,'b':1,'c':1}]:
            p,f=allocate(r,w)
            assert min(p.values())>=0 and sum(p.values())+f==r
    print('PASS: 12-decimal integer atomic precision')
    print('PASS: PPLNS share-weighted allocation; 0.5% fee')
    print('PASS: SOLO winner allocation; 0.5% fee')
    print('PASS: orphaned/pending blocks credited zero until confirmed')
    print('PASS: 5 FEEL payout threshold boundary')
    print('PASS: deterministic rounding and conservation of atomic rewards')
    print('NOT IMPLEMENTED: wallet transaction fee policy, actual Miningcore integration, wallet settlement')
    print('NOT READY FOR LIVE PAYOUTS')

if __name__=='__main__': test()
