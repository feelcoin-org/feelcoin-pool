import unittest
from audit_service import audit_blocks

H1 = 'a'*64
H2 = 'b'*64

class TestAudit(unittest.TestCase):
    def test_maturing_and_alternative(self):
        b = [{'height': 6983, 'hash': H1, 'status': 'pending'},
             {'height': 6983, 'hash': H2, 'status': 'pending'}]
        r = audit_blocks(b, 6986, {6983: H1})
        self.assertEqual([x['chain_status'] for x in r], ['maturing', 'alternative'])
        self.assertEqual([x['chain_confirmations'] for x in r], [3, None])
    def test_confirmed_requires_canonical(self):
        b = [{'height': 6900, 'hash': H1, 'status': 'pending'},
             {'height': 6900, 'hash': H2, 'status': 'confirmed'}]
        r = audit_blocks(b, 7000, {6900: H1})
        self.assertEqual(r[0]['chain_status'], 'confirmed')
        self.assertEqual(r[1]['chain_status'], 'alternative')
    def test_rpc_unavailable_fails_unverified(self):
        b = [{'height': 6983, 'hash': H1, 'status': 'confirmed'}]
        self.assertEqual(audit_blocks(b, None, {})[0]['chain_status'], 'unverified')
        self.assertEqual(audit_blocks(b, 6986, {})[0]['chain_status'], 'unverified')
    def test_mark_orphaned_only_when_recorded(self):
        b = [{'height': 6983, 'hash': H2, 'status': 'orphaned'}]
        self.assertEqual(audit_blocks(b, 6986, {6983: H1})[0]['chain_status'], 'orphaned')
    def test_bounds_and_untrusted_schema(self):
        b = [{'height': 999999999, 'hash': H1, 'status': 'confirmed'},
             {'height': 6983, 'hash': '<x>', 'status': 'confirmed'}]
        self.assertEqual([x['chain_status'] for x in audit_blocks(b, 6986, {6983: H1})],
                         ['unverified','unverified'])

if __name__ == '__main__':
    unittest.main()
