from ignis.entity.register import VanillaEntities
from ignis.entity.text import Text, new_text
from ignis.mgl64 import Vec3
from ignis.world.entity import EntityData
from std.testing import TestSuite, assert_equal, assert_true


def test_new_text() raises:
    var e = new_text[VanillaEntities]("hi", Vec3(1, 2, 3))
    assert_equal(e.data.name, "hi")
    assert_equal(e.position(), Vec3(1, 2, 3))
    assert_equal(e.identifier(), "dragonfly:text")
    assert_equal(
        VanillaEntities.network_identifier(e.state), "minecraft:falling_block"
    )
    assert_equal(Text().bbox(EntityData()).max(), Vec3())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
