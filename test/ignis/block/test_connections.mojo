from ignis.block.connections import (
    Connections,
    FireConnections,
    all_connections,
    all_fire_connections,
)
from ignis.world.block_state import Properties
from std.testing import TestSuite, assert_equal, assert_true


def test_connections() raises:
    var all = all_connections()
    assert_equal(len(all), 16)
    for i in range(16):
        assert_equal(Int(all[i].uint8()), i)
    var c = Connections(north=True, east=False, south=True, west=False)
    assert_equal(Int(c.uint8()), 5)
    assert_equal(
        String(c.properties(Properties())),
        "minecraft:connection_east=b:0,minecraft:connection_north=b:1,"
        + "minecraft:connection_south=b:1,minecraft:connection_west=b:0",
    )


def test_fire_connections() raises:
    var all = all_fire_connections()
    assert_equal(len(all), 32)
    for i in range(32):
        assert_equal(Int(all[i].uint8()), i)
    assert_true(FireConnections(bits=16).up)
    assert_equal(len(FireConnections().properties(Properties())), 5)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
