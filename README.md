# ⛏️ Feelcoin Mining Pool

**Official open-source RandomX mining pool for the Feelcoin (FEEL) network**

**Mining pool:** https://pool.feelcoin.org  
**Explorer:** https://explorer.feelcoin.org  
**Motto:** *In Feels We Trust.*

Feelcoin Mining Pool implements pool mining and share accounting for the Feelcoin blockchain. It is derived from the open-source [monero-pool](https://github.com/jtgrassie/monero-pool) project and adapted for Feelcoin.

## Features

- RandomX Proof-of-Work mining and CPU-oriented miner support.
- PPLNS (Pay Per Last N Shares) reward accounting.
- Dynamic miner difficulty and configurable difficulty retargeting.
- Live pool and network statistics, miner hashrate and worker monitoring.
- Wallet-address-based miner identification.
- Configurable fees and payout thresholds.
- Embedded web dashboard and Feelcoin Block Explorer integration.
- XMRig examples and systemd deployment support.

## Start mining

| Connection | Address |
| --- | --- |
| Standard | `pool.feelcoin.org:4242` |
| TLS | `pool.feelcoin.org:4244` |
| Algorithm | RandomX |
| Username | Your FEEL wallet address |
| Password | `x` |

**XMRig (standard):**

```bash
xmrig -o pool.feelcoin.org:4242 -u YOUR_FEELCOIN_WALLET_ADDRESS -p x
```

**XMRig (TLS):**

```bash
xmrig -o pool.feelcoin.org:4244 -u YOUR_FEELCOIN_WALLET_ADDRESS -p x --tls
```

Replace the example address with your own Feelcoin receiving address. Verify the pool's current settings on the live dashboard before mining.

## Pool settings documented in this repository

| Setting | Documented value |
| --- | --- |
| Reward scheme | PPLNS |
| Pool fee | 0.5% |
| Minimum payout threshold | 0.33 FEEL |
| Starting share difficulty | 100 |
| Fixed difficulty | Disabled globally |
| NiceHash difficulty | 280000 |
| Retarget interval | 30 seconds |
| Retarget ratio | 0.55 |
| Share multiplier | 2.0 |
| Self-select | Disabled |

**Note:** These are repository-documented settings, not a guarantee of current production configuration. Automatic payouts were noted as disabled during testing; check the live pool for their current status before relying on withdrawals.

PPLNS pays miners based on valid shares in a recent share window. Submitting an accepted share is not the same as finding a block.

## Mining dashboard

The source for the embedded dashboard is [`src/webui-embed.html`](src/webui-embed.html). The dashboard presents pool/network hashrate, connected miners, blockchain height, balances and mining setup instructions.

The internal web interface is configured separately from the public HTTPS dashboard. Internal IP addresses and admin ports should not be used as public download or mining instructions.

### Pool statistics API

In the documented local deployment, the dashboard reads a `/stats` endpoint:

```bash
curl http://127.0.0.1:4243/stats
```

This is a local example and is not intended as a public endpoint.

## Configuration

The pool's main configuration file is `pool.conf`. Example settings from the documented deployment:

```ini
pool-port = 4242
webui-port = 4243
rpc-host = 127.0.0.1
rpc-port = 35781
wallet-rpc-host = 127.0.0.1
wallet-rpc-port = 35784
pool-start-diff = 100
pool-fixed-diff = 0
pool-nicehash-diff = 280000
pool-fee = 0.005
payment-threshold = 0.33
retarget-time = 30
retarget-ratio = 0.55
share-mul = 2.0
disable-self-select = 1
disable-hash-check = 0
```

Review your deployment configuration and current software version before copying these values.

## Build from source

The pool builds against the Feelcoin source tree:

```bash
export MONERO_ROOT=/path/to/feelcoin
make release
```

The documented output binary is `build/release/feelcoin-pool`.

For a manual test in an isolated environment:

```bash
./build/release/feelcoin-pool pool.conf
```

### systemd deployment

A representative unit (adapt paths and service accounts to your host):

```ini
[Unit]
Description=Feelcoin Mining Pool
After=feelcoind.service
Requires=feelcoind.service

[Service]
User=feeladmin
WorkingDirectory=/home/feeladmin/feelcoin-pool
ExecStart=/home/feeladmin/feelcoin-pool/build/release/feelcoin-pool /home/feeladmin/feelcoin-pool/pool.conf
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

Enable and start the unit only after reviewing the paths and security settings.

## Network ports

| Service | Documented local port |
| --- | --- |
| Feelcoin daemon RPC | `35781` |
| Wallet RPC | `35784` |
| Standard mining | `4242` |
| Internal dashboard | `4243` |
| Public TLS mining | `4244` |

Keep daemon RPC and especially wallet RPC bound to localhost or a trusted private network. Never publish wallet files, private keys, recovery seeds, passwords or API credentials.

## Development and attribution

Feelcoin Pool builds on [jtgrassie's monero-pool](https://github.com/jtgrassie/monero-pool). Upstream licenses and copyright notices remain applicable. The Feelcoin-specific implementation adds its network configuration, branding and mining integrations.

See the repository [LICENSE](LICENSE) and source files for details.

## Official Feelcoin ecosystem

| Resource | Link |
| --- | --- |
| Website | https://feelcoin.org |
| Blockchain | https://github.com/feelcoin-org/feelcoin |
| Mining pool | https://pool.feelcoin.org |
| Block explorer | https://explorer.feelcoin.org |
| Web wallet | https://wallet.feelcoin.org |
| Paper wallet | https://paper.feelcoin.org |
| Android wallet | https://github.com/feelcoin-org/feelcoin-android |
| Desktop wallet | https://github.com/feelcoin-org/feelcoin-desktop |

---

## In Feels We Trust

## Contact

Official Feelcoin support and project contact:

[**support@feelcoin.org**](mailto:support@feelcoin.org)

---

## Support Feelcoin Development

Feelcoin is an open-source project.

If you would like to support ongoing development, infrastructure, documentation, testing, and community services, voluntary donations are welcome.

### FEEL

```text
FBx9yk7huEF9PjR33zABbUj915wFVw3LeXfHSX4F7eXMgvyrkaV7tEW4gDwZ9rnQdnRQ4RmZsfPyNezu2jFoLewZLCuS8iM
```

### Bitcoin

Bitcoin mainnet:

```text
bc1q78zv45v3tfek730x8es88vjavj0qej2n766h2f
```

### Ethereum

Ethereum mainnet:

```text
0x7eFC0c47ab555041c79a7269a37f46A835EB466f
```

Donations are entirely voluntary and do not provide ownership, governance rights, guaranteed returns, or preferential treatment.

These voluntary donation addresses are separate from the consensus-enforced Feelcoin development treasury.
