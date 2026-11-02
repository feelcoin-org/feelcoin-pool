#!/usr/bin/env python3
"""Non-mutating Feelcoin RPC-shape preflight for a possible Miningcore adapter.

Calls get_info, get_last_block_header and get_block_template on loopback.
Never submits a block, calls wallet RPC, modifies pool files or pays miners.
This checks only RPC format, NOT RandomX hashing, coinbase split or payouts.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from urllib import request
from urllib.parse import urlparse

HEX_64 = re.compile(r"^[0-9a-fA-F]{64}$")
HEX_EVEN = re.compile(r"^(?:[0-9a-fA-F]{2})+$")
MAX_REPLY_BYTES = 4 * 1024 * 1024


class ProbeError(Exception):
    """The daemon or returned data did not pass non-mutating checks."""


def read_pool_address(conf_path: Path) -> str:
    if not conf_path.is_file():
        raise ProbeError("Pool configuration file not found")
    for raw in conf_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("#") or "=" not in line:
            continue
        key, value = (part.strip() for part in line.split("=", 1))
        if key == "pool-wallet" and value:
            return value
    raise ProbeError("pool-wallet was not found in the given config file")


def check_loopback_rpc(url: str) -> None:
    parsed = urlparse(url)
    if (parsed.scheme != "http" or
            parsed.hostname not in ("localhost", "127.0.0.1", "::1") or
            parsed.path != "/json_rpc" or parsed.username or parsed.password or
            parsed.query or parsed.fragment or parsed.port is None):
        raise ProbeError("Only local, unauthenticated http://loopback:PORT/json_rpc URLs are allowed")


def rpc_call(url: str, method: str, params: dict | None = None) -> dict:
    if method not in ("get_info", "get_last_block_header", "get_block_template"):
        raise ProbeError("Method outside read-only allowlist")
    check_loopback_rpc(url)
    payload = {"jsonrpc": "2.0", "id": "feelcoin-preflight", "method": method}
    if params is not None:
        payload["params"] = params
    req = request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with request.urlopen(req, timeout=8) as response:
        raw = response.read(MAX_REPLY_BYTES + 1)
    if len(raw) > MAX_REPLY_BYTES:
        raise ProbeError("RPC reply exceeds size limit")
    try:
        msg = json.loads(raw)
    except (ValueError, UnicodeError) as exc:
        raise ProbeError("Daemon returned non-JSON data") from exc
    if not isinstance(msg, dict) or msg.get("error"):
        raise ProbeError("Daemon returned RPC error or invalid envelope for " + method)
    result = msg.get("result")
    if not isinstance(result, dict):
        raise ProbeError("Daemon returned no result object for " + method)
    return result


def positive_int(obj: dict, key: str, *, allow_zero: bool = False) -> int:
    value = obj.get(key)
    if type(value) is not int or (value < 0 if allow_zero else value <= 0):
        raise ProbeError("Invalid integer field: " + key)
    return value


def hex_bytes(obj: dict, key: str) -> int:
    value = obj.get(key)
    if not isinstance(value, str) or HEX_EVEN.fullmatch(value) is None:
        raise ProbeError("Invalid hex blob: " + key)
    return len(value) // 2


def examine(info: dict, header_response: dict, template: dict) -> dict:
    header = header_response.get("block_header")
    if not isinstance(header, dict):
        raise ProbeError("Missing block_header")

    node_height = positive_int(info, "height")
    head_height = positive_int(header, "height", allow_zero=True)
    template_height = positive_int(template, "height")
    chain_diff = positive_int(template, "difficulty")
    reserved = positive_int(template, "reserved_offset", allow_zero=True)
    blob_bytes = hex_bytes(template, "blocktemplate_blob")
    hash_blob_bytes = hex_bytes(template, "blockhashing_blob")
    seed = template.get("seed_hash")
    if not isinstance(seed, str) or HEX_64.fullmatch(seed) is None:
        raise ProbeError("Missing or malformed RandomX seed_hash")
    next_seed = template.get("next_seed_hash")
    if next_seed is not None and (not isinstance(next_seed, str) or
                                  HEX_64.fullmatch(next_seed) is None):
        raise ProbeError("Malformed next_seed_hash")

    # Requested reserve_size=17. Ensure the full requested region fits.
    if reserved + 17 > blob_bytes:
        raise ProbeError("Reserved template area out of range")
    if template_height < head_height or template_height > node_height + 2:
        raise ProbeError("Unexpected block-template height relative to tip")

    info_nettype = info.get("nettype")
    if info_nettype is not None and not isinstance(info_nettype, str):
        raise ProbeError("Invalid nettype")

    return {
        "rpc_shape": "pass",
        "node_nettype": info_nettype or "not supplied",
        "daemon_height": node_height,
        "last_block_height": head_height,
        "template_height": template_height,
        "template_difficulty": chain_diff,
        "template_blob_bytes": blob_bytes,
        "hashing_blob_bytes": hash_blob_bytes,
        "reserved_offset": reserved,
        "randomx_seed_present": True,
        "randomx_next_seed_present": next_seed is not None,
        "reward_accounting_verified": False,
        "randomx_hashing_verified": False,
        "solo_and_payouts_verified": False,
        "miningcore_compatible": "unproven",
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rpc-url", default="http://127.0.0.1:35781/json_rpc")
    parser.add_argument("--pool-conf", default="pool.conf")
    parser.add_argument("--wallet-address", help="Public mining address, not a private key")
    args = parser.parse_args(argv)

    try:
        check_loopback_rpc(args.rpc_url)
        wallet = args.wallet_address or read_pool_address(Path(args.pool_conf))
        if not 40 <= len(wallet) <= 127 or not wallet.isalnum():
            raise ProbeError("Expected a public Feelcoin wallet address, not a secret")
        info = rpc_call(args.rpc_url, "get_info")
        header = rpc_call(args.rpc_url, "get_last_block_header")
        template = rpc_call(
            args.rpc_url, "get_block_template",
            {"wallet_address": wallet, "reserve_size": 17},
        )
        result = examine(info, header, template)
    except (ProbeError, OSError, ValueError) as exc:
        # Avoid logging URLs, response bodies, wallet values or credentials.
        print(json.dumps({"rpc_shape": "fail", "reason": type(exc).__name__}), file=sys.stderr)
        return 1

    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
