from ignis.world.block_state import Properties
from ignis.world.network_block_hash import (
    UNKNOWN_BLOCK_HASH,
    network_block_hash,
)
from std.testing import TestSuite, assert_equal


def test_hashes_from_dragonfly_vectors() raises:
    # Lines from test/data/world/block_states_sample.txt.
    var scratch = List[UInt8]()
    assert_equal(
        network_block_hash("minecraft:cyan_terracotta", Properties(), scratch),
        0x3A0B8F85,
    )
    var door = (
        Properties()
        .with_byte("door_hinge_bit", 1)
        .with_string("minecraft:cardinal_direction", "east")
        .with_byte("open_bit", 0)
        .with_byte("upper_block_bit", 0)
    )
    assert_equal(
        network_block_hash("minecraft:warped_door", door, scratch), 0x408322C1
    )
    var stairs = (
        Properties()
        .with_string("minecraft:corner", "inner_right")
        .with_byte("upside_down_bit", 1)
        .with_int("weirdo_direction", 0)
    )
    assert_equal(
        network_block_hash("minecraft:nether_brick_stairs", stairs, scratch),
        0x3E720A28,
    )


def test_unknown() raises:
    var scratch = List[UInt8]()
    assert_equal(
        network_block_hash("minecraft:unknown", Properties(), scratch),
        UNKNOWN_BLOCK_HASH,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
