from ignis.block.dirt import Dirt
from ignis.block.hash import (
    HASH_AIR,
    HASH_BEDROCK,
    HASH_CUSTOM_BLOCK_BASE,
    HASH_DIRT,
    HASH_WOOL,
    AnyBlock,
    hash_block,
    unhash_block,
)
from ignis.block.stone import Stone
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_values_match_go_iota() raises:
    assert_equal(HASH_AIR, 0)
    assert_equal(HASH_BEDROCK, 15)
    assert_equal(HASH_WOOL, 224)
    assert_equal(HASH_CUSTOM_BLOCK_BASE, 225)


def test_any_block() raises:
    var b = AnyBlock(Dirt(coarse=True))
    assert_equal(b.kind, HASH_DIRT)
    assert_equal(b.state, 1)
    assert_true(b.is_a[Dirt]())
    assert_false(b.is_a[Stone]())
    assert_true(b.get[Dirt]().value().coarse)
    assert_false(Bool(b.get[Stone]()))
    # Go hashBlock: base | state << 16.
    assert_equal(hash_block(b), HASH_DIRT | (1 << 16))
    assert_true(unhash_block(hash_block(b)) == b)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
