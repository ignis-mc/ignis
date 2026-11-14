from ignis.item.register import vanilla_item_registry
from std.testing import TestSuite, assert_equal, assert_true


def test_vanilla_item_registry() raises:
    var reg = vanilla_item_registry()
    # 6 item values and 7 block item values.
    assert_equal(len(reg.items()), 13)
    assert_true(reg.item_by_name("minecraft:smooth_stone", 0))
    assert_true(reg.item_by_name("minecraft:shears", 0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
