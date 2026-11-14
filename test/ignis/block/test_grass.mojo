from ignis.block.grass import Grass
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_hash_round_trips() raises:
    for b in Grass.all_states():
        assert_true(Grass.from_hash(b.hash()) == b)


def test_encode_block() raises:
    assert_equal(String(Grass().encode_block()), "minecraft:grass_block{}")


def test_encode_item() raises:
    assert_equal(Grass().encode_item().name, "minecraft:grass_block")
    assert_equal(len(Grass.all_items()), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
