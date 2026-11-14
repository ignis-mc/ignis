from ignis.block.stone import Stone
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_hash_round_trips() raises:
    for b in Stone.all_states():
        assert_true(Stone.from_hash(b.hash()) == b)


def test_encode_block() raises:
    assert_equal(String(Stone().encode_block()), "minecraft:stone{}")
    assert_equal(
        String(Stone(smooth=True).encode_block()), "minecraft:smooth_stone{}"
    )


def test_encode_item() raises:
    assert_equal(Stone().encode_item().name, "minecraft:stone")
    assert_equal(
        Stone(smooth=True).encode_item().name, "minecraft:smooth_stone"
    )
    assert_equal(len(Stone.all_items()), 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
