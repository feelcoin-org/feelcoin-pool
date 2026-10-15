#!/usr/bin/env python3
"""Feelcoin Pool read-only canonical-chain audit endpoint.

Only GET /api/pool-chain-audit is served, on loopback. Never proxies client RPC
or forwards arbitrary method names, request bodies, wallet credentials, etc.
"""
import json
import logging
import os
import re
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from concurrent.futures import ThreadPoolExecutor, as_completed

POOL_URL = 'http://127.0.0.1:4243/blocks'
DAEMON_URL = 'http://127.0.0.1:35781/json_rpc'
LISTEN_HOST = '127.0.0.1'
LISTEN_PORT = 16083
CACHE_SECONDS = 15
MAX_BLOCKS = 25
MAX_HEIGHT_QUERIES = 12
HASH_RE = re.compile(r'^[0-9a-fA-F]{64}$')
_cache = {'ts': 0.0, 'data': None}
_lock = threading.Lock()


def fetch_json(url, payload=None):
    headers = {'Accept': 'application/json'}
    if payload is not None:
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=json.dumps(payload).encode() if payload is not None else None, headers=headers)
    with urllib.request.urlopen(req, timeout=4) as resp:
        if resp.status != 200:
            raise RuntimeError('unexpected HTTP status')
        raw = resp.read(512_000)
        return json.loads(raw)


def rpc(method, params=None):
    if method not in ('get_last_block_header', 'get_block_header_by_height'):
        raise ValueError('RPC method is not allowed')
    req = {'jsonrpc': '2.0', 'id': 'pool-chain-audit', 'method': method, 'params': params or {}}
    data = fetch_json(DAEMON_URL, req)
    if data.get('error') or not isinstance(data.get('result'), dict):
        raise RuntimeError('daemon RPC rejected request')
    return data['result']


def number(value, default=None):
    try:
        v = int(value)
        return v if v >= 0 else default
    except (ValueError, TypeError):
        return default


def audit_blocks(raw_blocks, tip, headers):
    """Pure conversion. Unknown chain data never becomes 'confirmed'."""
    result = []
    for b in raw_blocks[:MAX_BLOCKS]:
        if not isinstance(b, dict):
            continue
        entry = dict(b)
        height = number(b.get('height'))
        block_hash = str(b.get('hash', '')).lower()
        required = number(b.get('required_confirmations'), 60) or 60
        status = 'unverified'
        conf = None
        if tip is not None and height is not None and height <= tip and HASH_RE.fullmatch(block_hash):
            chain_hash = headers.get(height)
            if chain_hash and HASH_RE.fullmatch(chain_hash):
                if block_hash == chain_hash.lower():
                    conf = min(tip - height, required)
                    status = 'confirmed' if conf >= required else 'maturing'
                elif str(b.get('status', '')).lower() == 'orphaned':
                    status = 'orphaned'
                else:
                    status = 'alternative'
        entry['chain_status'] = status
        entry['chain_confirmations'] = conf
        result.append(entry)
    return result


def compute_audit():
    source = fetch_json(POOL_URL)
    raw_blocks = source.get('blocks', [])
    if not isinstance(raw_blocks, list):
        raise RuntimeError('Unexpected pool blocks schema')
    raw_blocks = raw_blocks[:MAX_BLOCKS]
    tip = None
    headers = {}
    try:
        header = rpc('get_last_block_header').get('block_header', {})
        tip = number(header.get('height'))
    except Exception as exc:
        logging.warning('Daemon tip unavailable: %s', type(exc).__name__)

    if tip is not None:
        unique_heights = []
        for b in raw_blocks:
            h = number(b.get('height')) if isinstance(b, dict) else None
            if h is not None and h <= tip and h not in unique_heights:
                unique_heights.append(h)
        def chain_hash_at_height(h):
            header = rpc('get_block_header_by_height', {'height': h}).get('block_header', {})
            chain_hash = str(header.get('hash', '')).lower()
            return h, chain_hash if HASH_RE.fullmatch(chain_hash) else None

        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = {executor.submit(chain_hash_at_height, h): h
                       for h in unique_heights[:MAX_HEIGHT_QUERIES]}
            for future in as_completed(futures):
                try:
                    height, value = future.result()
                    if value:
                        headers[height] = value
                except Exception as exc:
                    logging.warning('Header at height %d unavailable: %s', futures[future], type(exc).__name__)

    blocks = audit_blocks(raw_blocks, tip, headers)
    counts = {kind: sum(1 for x in blocks if x['chain_status'] == kind)
              for kind in ('maturing', 'confirmed', 'alternative', 'orphaned', 'unverified')}
    return {'blocks': blocks, 'chain_height': tip,
            'checked_at': int(time.time()), 'counts': counts,
            'sample_count': len(blocks), 'source': 'canonical-chain-audit-v1'}


def get_cached_audit():
    with _lock:
        now = time.monotonic()
        if _cache['data'] is not None and now - _cache['ts'] <= CACHE_SECONDS:
            return _cache['data']
        data = compute_audit()
        _cache.update({'data': data, 'ts': now})
        return data


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != '/api/pool-chain-audit':
            self.send_error(404)
            return
        try:
            data = get_cached_audit()
            raw = json.dumps(data, separators=(',', ':')).encode('utf-8')
            status = 200
        except Exception as exc:
            logging.error('Audit unavailable: %s', type(exc).__name__)
            raw = b'{"error":"temporarily unavailable"}'
            status = 503
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_POST(self):
        self.send_error(405)

    def log_message(self, format_string, *args):
        logging.info(format_string, *args)


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
    ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Handler).serve_forever()
