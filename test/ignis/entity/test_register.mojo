from ignis.entity.register import VanillaEntities
from ignis.entity.text import Text
from minecraft.nbt.tree import Tree
from ignis.world.entity import EntityData
from std.testing import TestSuite, assert_true


def test_lookup() raises:
    var t = Tree()
    var d = EntityData()
    assert_true(VanillaEntities.decode_nbt("dragonfly:text", t, t.root(), d))
    assert_true(not VanillaEntities.decode_nbt("minecraft:pig", t, t.root(), d))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
