"""Offline EA source-contract tests. No MetaTrader runtime or live orders."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [ROOT / 'ea_mt4/HandlivPanel.mq4', ROOT / 'ea_mt5/HandlivPanel.mq5']

class AutomationContract(unittest.TestCase):
    def test_opt_in_and_distinct_readiness(self):
        for path in SOURCES:
            source = path.read_text(encoding='utf-8-sig')
            with self.subTest(platform=path.suffix):
                import re
                self.assertTrue(bool(re.search(r'(?:input|extern) bool\s+InpAllowAutomation\s*=\s*false;', source)), 'opt-in missing')
                for expected in ['\\"automation_v1\\":true', '\\"automation_ready\\":', 'AutomationReady()']:
                    self.assertTrue(expected in source, 'capability/readiness missing')

    def test_execution_is_fail_closed_and_durably_claimed(self):
        for path in SOURCES:
            source = path.read_text(encoding='utf-8-sig')
            expected = ['AutomationValidate(', 'AutomationExecute(', 'CommandClaim(',
                        'FileFlush(', 'FILE_COMMON', 'FileClose(claim)',
                        'AutomationOccupied(', 'TimeGMT()', '20261002',
                        'JsonRawField(', 'UtcExpiry(', 'ValidUuid(', 'ExactVolume(']
            for marker in expected:
                self.assertTrue(marker in source, f'{path.suffix}: missing safety guard {marker}')
            if path.suffix == '.mq5':
                for marker in ['ACCOUNT_MARGIN_MODE_RETAIL_HEDGING', 'ORDER_MAGIC',
                               'POSITION_MAGIC', 'TRADE_RETCODE_DONE_PARTIAL']:
                    self.assertTrue(marker in source, f'MT5: missing {marker}')

    def test_mandatory_atr_protection_and_complete_position_snapshot(self):
        for path in SOURCES:
            source = path.read_text(encoding='utf-8-sig')
            for marker in ['ProtectionParameters(', 'ProtectionPrice(', 'ProtectionPair(',
                           'ClosedCandleAtr(', 'AutomationPositionsJson(',
                           '\\"automation_protection_v1\\":true', '\\"automation_positions\\":']:
                self.assertTrue(marker in source, f'{path.suffix}: missing protection/snapshot {marker}')

if __name__ == '__main__':
    unittest.main()
