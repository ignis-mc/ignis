from ignis.item.recipe.item_tag import ItemTags, new_item_tag
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_parse_and_contains() raises:
    var json = String('{"minecraft:planks": ["minecraft:oak_planks"]}')
    var tags = ItemTags.parse(json.as_bytes())
    var t = new_item_tag(tags, "minecraft:planks", 2)
    assert_equal(t.count(), 2)
    assert_true(t.contains("minecraft:oak_planks"))
    assert_false(t.contains("minecraft:stone"))
    assert_false(t.empty())
    assert_true(new_item_tag(tags, "minecraft:planks", 0).empty())
    assert_equal(new_item_tag(tags, "minecraft:none", -3).count(), 0)


def test_vanilla_tags() raises:
    var tags = ItemTags.load()
    var t = new_item_tag(tags, "minecraft:planks", 1)
    assert_true(t.contains("minecraft:oak_planks"))
    assert_true(len(tags.items("minecraft:boat")) > 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
