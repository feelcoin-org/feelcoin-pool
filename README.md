<p align="center">
  <img src="https://i.imgur.com/VPorAY4.jpeg" alt="Feelcoin Logo" width="170">
</p>

<h1 align="center">Feelcoin Mining Pool</h1>

<p align="center">
  Official RandomX mining pool for the Feelcoin network.
</p>

<p align="center">
  <strong>In Feels We Trust</strong>
</p>

Overview

Feelcoin Mining Pool is the mining pool software for the Feelcoin network.

It provides RandomX mining, PPLNS reward accounting, dynamic miner difficulty, live statistics, miner monitoring, an embedded web dashboard, and integration with the Feelcoin Block Explorer.

The pool is derived from the open-source monero-pool project and adapted for the Feelcoin network.

Features

RandomX Proof-of-Work mining

CPU-friendly mining

PPLNS reward accounting

Dynamic mining difficulty

Automatic difficulty retargeting

Live pool statistics

Network statistics

Miner dashboard

Miner hashrate monitoring

Miner balance tracking

Feelcoin wallet-based miner identification

Configurable pool fee

Configurable payout threshold

NiceHash difficulty support

Embedded professional web dashboard

Feelcoin Block Explorer integration

XMRig setup examples

systemd deployment support

Live Feelcoin Services

Mining Pool

pool.feelcoin.online:4242

Pool Dashboard

http://162.35.27.43:4243

Block Explorer

https://explorer.feelcoin.online

Start Mining

Feelcoin can be mined using XMRig or another compatible RandomX miner.

Connection Information

Pool Address: 162.35.27.43

Pool Port: 4242

Algorithm: RandomX

Username: your Feelcoin wallet address

Password: x

TLS/SSL: enabled on pool.feelcoin.online:4244

XMRig Quick Start

xmrig -o pool.feelcoin.online:4242 -u YOUR_FEELCOIN_WALLET_ADDRESS -p x

Replace YOUR_FEELCOIN_WALLET_ADDRESS with your own Feelcoin wallet address.

XMRig Configuration Example

{
  "autosave": true,
  "cpu": {
    "enabled": true,
    "huge-pages": true,
    "yield": true
  },
  "opencl": false,
  "cuda": false,
  "pools": [
    {
      "url": "pool.feelcoin.online:4242",
      "user": "YOUR_FEELCOIN_WALLET_ADDRESS",
      "pass": "x",
      "keepalive": true
    }
  ]
}

Current Pool Configuration

Setting

Value

Algorithm

RandomX

Reward Scheme

PPLNS

Mining Port

4242

Pool Dashboard Port

4243

Pool Fee

0.5%

Minimum Payout

0.33 FEEL

Starting Difficulty

100

Fixed Difficulty

Disabled globally

NiceHash Difficulty

280000

Difficulty Retarget

30 seconds

Retarget Ratio

0.55

Share Multiplier

2.0

TLS Mining

Enabled

Standard endpoint:

pool.feelcoin.online:4242

Secure TLS endpoint:

pool.feelcoin.online:4244

XMRig TLS:

xmrig -o pool.feelcoin.online:4244 -u YOUR_FEELCOIN_WALLET_ADDRESS -p x --tls

Self Select

Disabled

Automatic Payouts

Disabled during testing

Pool Fee

The current pool fee is 0.5%.

Configuration:

pool-fee = 0.005

A dedicated Feelcoin fee wallet can be configured with:

pool-fee-wallet = YOUR_FEELCOIN_FEE_WALLET

Minimum Payout

The configured minimum payout threshold is 0.33 FEEL.

Configuration:

payment-threshold = 0.33

Automatic payouts may remain disabled while the network and pool are being tested.

Reward Scheme

Feelcoin Pool uses PPLNS, which means Pay Per Last N Shares.

Miner rewards are calculated according to the valid shares contributed during the pool's active share window.

An accepted share means that the miner submitted valid mining work to the pool. It does not mean that a block has been found immediately.

Difficulty Management

The pool starts miners at difficulty 100 and automatically adjusts mining difficulty according to miner performance.

Current configuration:

pool-start-diff = 100
pool-fixed-diff = 0
pool-nicehash-diff = 280000
retarget-time = 30
retarget-ratio = 0.55

Pool Configuration

The main pool configuration file is pool.conf.

Current configuration structure:

pool-listen = 0.0.0.0
pool-port = 4242
pool-ssl-port =
pool-syn-backlog = 16

webui-listen = 0.0.0.0
webui-port = 4243

rpc-host = 127.0.0.1
rpc-port = 35781

wallet-rpc-host = 127.0.0.1
wallet-rpc-port = 35784

rpc-timeout = 15
idle-timeout = 150
template-timeout = 45

pool-start-diff = 100
pool-fixed-diff = 0
pool-nicehash-diff = 280000

pool-fee = 0.005
payment-threshold = 0.33

share-mul = 2.0
retarget-time = 30
retarget-ratio = 0.55

disable-self-select = 1
disable-hash-check = 0
disable-payouts = 1

processes = 1

Feelcoin Daemon

The mining pool requires a running Feelcoin daemon.

Default daemon RPC endpoint: 127.0.0.1:35781

The pool uses the daemon to:

obtain block templates

read blockchain height

retrieve network difficulty

retrieve network information

submit newly found blocks

The daemon RPC should remain bound to localhost unless there is a specific reason to expose it.

Feelcoin Wallet RPC

Pool payout processing can use the Feelcoin wallet RPC service.

Default wallet RPC endpoint: 127.0.0.1:35784

Configuration:

wallet-rpc-host = 127.0.0.1
wallet-rpc-port = 35784

Do not expose wallet RPC publicly.

Build

The pool is compiled against the Feelcoin source tree.

Set the Feelcoin source directory:

export MONERO_ROOT=/home/feeladmin/feelcoin

Build the pool:

make release

The resulting pool binary is build/release/feelcoin-pool.

Run Manually

cd /home/feeladmin/feelcoin-pool
./build/release/feelcoin-pool pool.conf

Run in the background:

nohup ./build/release/feelcoin-pool pool.conf > pool.log 2>&1 &

systemd Service

Feelcoin Pool can run automatically using systemd.

[Unit]
Description=Feelcoin Mining Pool
After=feelcoind.service
Requires=feelcoind.service

[Service]
User=feeladmin
WorkingDirectory=/home/feeladmin/feelcoin-pool
Environment=MONERO_ROOT=/home/feeladmin/feelcoin
ExecStart=/home/feeladmin/feelcoin-pool/build/release/feelcoin-pool /home/feeladmin/feelcoin-pool/pool.conf
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

Enable at boot:

sudo systemctl enable feelcoin-pool

Start:

sudo systemctl start feelcoin-pool

Restart:

sudo systemctl restart feelcoin-pool

Status:

sudo systemctl status feelcoin-pool

Web Dashboard

Feelcoin Pool includes a custom embedded web dashboard.

Frontend source: src/webui-embed.html

The dashboard displays:

pool hashrate

network hashrate

blockchain height

connected miners

pool fee

minimum payout

mining connection information

XMRig setup instructions

miner statistics

miner balance

pool configuration

FAQ

Feelcoin Block Explorer link

The frontend is embedded directly into the pool executable.

After changing src/webui-embed.html, rebuild the pool:

export MONERO_ROOT=/home/feeladmin/feelcoin
make release

Then restart:

sudo systemctl restart feelcoin-pool

Pool Statistics API

The web server exposes pool statistics through /stats.

Example:

curl http://127.0.0.1:4243/stats

The dashboard uses this endpoint to retrieve live pool and miner information.

Miner Dashboard

Miners can enter their Feelcoin wallet address in the web interface to retrieve pool statistics.

Depending on available pool data, the dashboard can display:

miner hashrate

balance due

wallet identifier

pool connection status

Feelcoin Block Explorer

Feelcoin Pool integrates with the Feelcoin Block Explorer.

Live explorer: https://explorer.feelcoin.online

GitHub: https://github.com/feelcoin-org/feelcoin-explorer

The explorer currently provides:

blockchain height

network difficulty

estimated network hashrate

latest blocks

block height search

block hash search

transaction hash search

mempool statistics

network connection information

Network Ports

Service

Port

Feelcoin Daemon RPC

35781

Feelcoin Wallet RPC

35784

Mining Pool

4242

Pool Dashboard

4243

Block Explorer

8081

Project Structure

feelcoin-pool/
├── src/
│   ├── pool.c
│   ├── webui.c
│   ├── webui.h
│   └── webui-embed.html
├── rxi/
├── tools/
├── build/
├── pool.conf
├── Makefile
├── LICENSE
└── README.md

Security

For production deployment:

keep daemon RPC private

keep wallet RPC private

do not expose wallet RPC directly to the internet

do not commit wallet files

do not commit private keys

do not commit seed phrases

do not commit passwords

do not commit API credentials

use firewall rules

add HTTPS for public web services

TLS mining available on pool.feelcoin.online:4244

keep the operating system updated

monitor pool and daemon logs

Feelcoin Repositories

Feelcoin Core

https://github.com/feelcoin-org/feelcoin

Feelcoin Mining Pool

https://github.com/feelcoin-org/feelcoin-pool

Feelcoin Block Explorer

https://github.com/feelcoin-org/feelcoin-explorer

Feelcoin

Feelcoin is an independent cryptocurrency project using RandomX Proof-of-Work.

Project motto:

In Feels We Trust

<p align="center">
  <img src="https://i.imgur.com/VPorAY4.jpeg" alt="Feelcoin" width="120">
</p>

Upstream Attribution

Feelcoin Mining Pool is derived from the open-source monero-pool project by jtgrassie and has been adapted for the Feelcoin network.

Original upstream repository: https://github.com/jtgrassie/monero-pool

The original project's copyright notices and licensing requirements remain applicable where required.

License

See the repository LICENSE file for licensing information.

<p align="center">
  <strong>Feelcoin Network</strong>
</p>

<p align="center">
  <strong>In Feels We Trust</strong>
</p>


## Feelcoin Wallets

Web Wallet:

https://wallet.feelcoin.online

Paper Wallet:

https://paper.feelcoin.online

The web services are published through HTTPS and their application
backends listen only on localhost.
