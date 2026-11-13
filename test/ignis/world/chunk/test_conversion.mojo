from ignis.world.chunk.conversion import Upgrades
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_legacy_mappings() raises:
    var up = Upgrades.load()
    assert_true(up.legacy_count() > 1000)
    # Pre-1.13 stone with meta 1 is granite in the flattened state of
    # legacy_states.nbt.
    var g = up.upgrade_legacy_entry("minecraft:stone", 1).value().copy()
    assert_equal(g.name, "minecraft:stone")
    assert_equal(
        String(g.properties.get("stone_type").value().string), "granite"
    )
    # Unknown metas fall back to meta 0.
    var s = up.upgrade_legacy_entry("minecraft:stone", 999).value().copy()
    assert_equal(String(s.properties.get("stone_type").value().string), "stone")
    assert_false(Bool(up.upgrade_legacy_entry("minecraft:no_such_block", 0)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
