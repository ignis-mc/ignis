from ignis.item.sherd_type import SherdType, sherd_types
from std.testing import TestSuite, assert_equal


def test_values() raises:
    var all = sherd_types()
    assert_equal(len(all), 23)
    for i in range(len(all)):
        assert_equal(Int(all[i].uint8()), i)
        assert_equal(all[i], SherdType(i))


def test_names() raises:
    assert_equal(String(SherdType.ARMS_UP), "arms_up")
    assert_equal(String(SherdType.SCRAPE), "scrape")
    assert_equal(String(SherdType.ARMS_UP.name()), "arms_up")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
