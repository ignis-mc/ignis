from ignis.item.durability import DurabilityInfo
from ignis.item.shears import Shears
from std.testing import TestSuite, assert_true


def test_shears_durability_info() raises:
    assert_true(
        Shears().durability_info()
        == DurabilityInfo(
            max_durability=238,
            attack_durability=0,
            break_durability=1,
            persistent=False,
        )
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
