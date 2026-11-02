"""Offline tests for the read-only Feelcoin Miningcore RPC-shape preflight."""
import io
import json
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import feelcoin_miningcore_probe as probe


def fixture():
    header = {"block_header": {"height": 100}}
    info = {"height": 101, "nettype": "mainnet"}
    template = {
        "height": 101,
        "difficulty": 3000,
        "reserved_offset": 25,
        "blocktemplate_blob": "ab" * 200,
        "blockhashing_blob": "aa" * 120,
        "seed_hash": "dd" * 32,
        "next_seed_hash": "ee" * 32,
    }
    return info, header, template


class FakeHTTPReply:
    def __init__(self, result):
        self.body = json.dumps({"jsonrpc": "2.0", "result": result, "id": "feelcoin-preflight"}).encode()

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def read(self, limit):
        return self.body[:limit]


class RpcProbeTest(unittest.TestCase):
    def test_successful_shape_does_not_claim_reward_or_randomx_validation(self):
        output = probe.examine(*fixture())
        self.assertEqual(output["rpc_shape"], "pass")
        self.assertFalse(output["reward_accounting_verified"])
        self.assertFalse(output["randomx_hashing_verified"])
        self.assertFalse(output["solo_and_payouts_verified"])
        self.assertEqual(output["miningcore_compatible"], "unproven")

    def test_invalid_reserve_range_fails(self):
        info, header, template = fixture()
        template["reserved_offset"] = 198
        with self.assertRaises(probe.ProbeError):
            probe.examine(info, header, template)

    def test_corrupt_seed_fails(self):
        info, header, template = fixture()
        template["seed_hash"] = "xx" * 32
        with self.assertRaises(probe.ProbeError):
            probe.examine(info, header, template)

    def test_non_integer_difficulty_fails(self):
        info, header, template = fixture()
        template["difficulty"] = 3.5
        with self.assertRaises(probe.ProbeError):
            probe.examine(info, header, template)

    def test_non_loopback_endpoints_forbidden(self):
        for url in (
            "http://example.com:35781/json_rpc",
            "https://127.0.0.1:35781/json_rpc",
            "http://127.0.0.1:35784/jsonrpc",
            "http://user:password@localhost:35781/json_rpc",
            "http://localhost:35781/json_rpc?method=transfer",
        ):
            with self.subTest(url=url), self.assertRaises(probe.ProbeError):
                probe.check_loopback_rpc(url)

    def test_mutating_rpc_methods_cannot_be_called(self):
        with self.assertRaises(probe.ProbeError):
            probe.rpc_call("http://127.0.0.1:35781/json_rpc", "submit_block")

    def test_probe_uses_only_allowlisted_methods(self):
        info, header, template = fixture()
        results = iter([info, header, template])
        seen = []

        def fake_urlopen(req, timeout):
            payload = json.loads(req.data)
            seen.append(payload["method"])
            self.assertEqual(timeout, 8)
            self.assertEqual(req.method, "POST")
            return FakeHTTPReply(next(results))

        with mock.patch.object(probe.request, "urlopen", side_effect=fake_urlopen):
            output = []
            for method, params in (
                ("get_info", None),
                ("get_last_block_header", None),
                ("get_block_template", {"wallet_address": "F" * 90, "reserve_size": 17}),
            ):
                output.append(probe.rpc_call("http://127.0.0.1:35781/json_rpc", method, params))
            self.assertEqual(probe.examine(*output)["rpc_shape"], "pass")
            self.assertEqual(seen, ["get_info", "get_last_block_header", "get_block_template"])

    def test_rpc_error_rejected(self):
        class ErrorHTTPReply(FakeHTTPReply):
            def __init__(self):
                self.body = b'{"error":{"code":-1,"message":"not available"}}'

        with mock.patch.object(probe.request, "urlopen", return_value=ErrorHTTPReply()):
            with self.assertRaises(probe.ProbeError):
                probe.rpc_call("http://127.0.0.1:35781/json_rpc", "get_info")


if __name__ == "__main__":
    unittest.main()
