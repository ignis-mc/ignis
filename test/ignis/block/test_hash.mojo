from ignis.block.hash import (
    HASH_AIR,
    HASH_BEDROCK,
    HASH_CUSTOM_BLOCK_BASE,
    HASH_WOOL,
)
from std.testing import TestSuite, assert_equal


def test_values_match_go_iota() raises:
    assert_equal(HASH_AIR, 0)
    assert_equal(HASH_BEDROCK, 15)
    assert_equal(HASH_WOOL, 224)
    assert_equal(HASH_CUSTOM_BLOCK_BASE, 225)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
