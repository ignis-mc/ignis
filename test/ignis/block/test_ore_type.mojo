from ignis.block.ore_type import OreType, ore_types
from std.testing import TestSuite, assert_equal


def test_ore_type() raises:
    assert_equal(len(ore_types()), 2)
    assert_equal(OreType.STONE.prefix(), "")
    assert_equal(OreType.DEEPSLATE.prefix(), "deepslate_")
    assert_equal(OreType.STONE.hardness(), 3.0)
    assert_equal(OreType.DEEPSLATE.hardness(), 4.5)
    assert_equal(String(OreType.DEEPSLATE), "deepslate")
    assert_equal(OreType.DEEPSLATE.name(), "Deepslate")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
