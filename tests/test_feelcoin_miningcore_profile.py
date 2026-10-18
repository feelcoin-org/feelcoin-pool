"""Offline, structural verification of the proposed Feelcoin Miningcore coin entry.

This verifies an address/hash *profile*, not block validation, rewards,
network compatibility, or payout correctness.
"""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROFILE = ROOT / "research" / "miningcore" / "feelcoin.coin.json"
EXPECTED = {
    "hash": "randomx",
    "hashVariant": 0,
    "blobType": 0,
    "smallestUnit": 10 ** 12,
    "addressPrefix": 84,
    "addressPrefixTestnet": 90,
    "addressPrefixStagenet": 96,
    "addressPrefixIntegrated": 85,
    "addressPrefixIntegratedTestnet": 91,
    "addressPrefixIntegratedStagenet": 97,
    "subAddressPrefix": 86,
    "subAddressPrefixTestnet": 92,
    "subAddressPrefixStagenet": 98,
}


class FeelcoinMiningcoreProfileTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile = json.loads(PROFILE.read_text(encoding="utf-8"))

    def test_unique_non_monero_coin(self):
        self.assertEqual(list(self.profile), ["feelcoin"])
        feel = self.profile["feelcoin"]
        self.assertEqual(feel["symbol"], "FEEL")
        self.assertEqual(feel["family"], "cryptonote")
        self.assertEqual(feel["name"], "Feelcoin")
        self.assertEqual(feel["canonicalName"], "Feelcoin")

    def test_constants_match_reviewed_feelcoin_core(self):
        feel = self.profile["feelcoin"]
        for key, expected in EXPECTED.items():
            with self.subTest(key=key):
                self.assertIn(key, feel)
                self.assertEqual(feel[key], expected)
                self.assertEqual(type(feel[key]), type(expected))

    def test_profile_neither_contains_wallets_nor_claims_reward_compatibility(self):
        profile = self.profile["feelcoin"]
        forbidden = {
            "wallet", "address", "privateKey", "seed", "paymentProcessing",
            "payoutScheme", "poolFee", "minerReward", "treasuryFee",
            "rewardMultiplier", "blockrewardMultiplier"
        }
        self.assertFalse(set(profile).intersection(forbidden))

    def test_upstream_cryptonote_schema_keys_when_supplied(self):
        # Optional argv[1] = pinned candidate's src/Miningcore/coins.json.
        if len(sys.argv) < 2 or not Path(sys.argv[1]).is_file():
            self.skipTest("Upstream Miningcore coins.json not supplied")
        upstream = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
        reference = upstream["monero"]
        feel = self.profile["feelcoin"]
        essential_keys = (
            "family", "hash", "hashVariant", "blobType", "smallestUnit",
            "addressPrefix", "addressPrefixTestnet", "addressPrefixStagenet",
            "addressPrefixIntegrated", "addressPrefixIntegratedTestnet",
            "addressPrefixIntegratedStagenet", "subAddressPrefix",
            "subAddressPrefixTestnet", "subAddressPrefixStagenet"
        )
        for key in essential_keys:
            with self.subTest(key=key):
                self.assertIn(key, reference)
                self.assertIn(key, feel)
                self.assertEqual(type(feel[key]), type(reference[key]))


if __name__ == "__main__":
    # Running with argv[1] uses the test field above; don't pass it to unittest.
    unittest.main(argv=[sys.argv[0]], verbosity=2)
