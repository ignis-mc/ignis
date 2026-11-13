from ignis.block.dirt import Dirt
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_hash_round_trips() raises:
    for b in Dirt.all_states():
        assert_true(Dirt.from_hash(b.hash()) == b)


def test_encode_block() raises:
    assert_equal(String(Dirt().encode_block()), "minecraft:dirt{}")
    assert_equal(
        String(Dirt(coarse=True).encode_block()), "minecraft:coarse_dirt{}"
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
