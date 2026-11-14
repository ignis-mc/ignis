from ignis.block.air import Air
from ignis.world.dimension import NETHER, OVERWORLD
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_hash_round_trips() raises:
    for b in Air.all_states():
        assert_true(Air.from_hash(b.hash()) == b)


def test_encode_block() raises:
    assert_equal(String(Air().encode_block()), "minecraft:air{}")


def test_behaviour() raises:
    assert_equal(Air().light_diffusion_level(), 0)
    assert_true(Air().portal_interior(NETHER))
    assert_false(Air().portal_interior(OVERWORLD))
    assert_false(Air().has_liquid_drops())


def test_encode_item() raises:
    assert_equal(Air().encode_item().name, "minecraft:air")
    assert_equal(len(Air.all_items()), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
