from ignis.block.register import vanilla_block_registry
from ignis.item.creative.creative import load_creative_items
from ignis.item.register import vanilla_item_registry
from std.testing import TestSuite, assert_equal, assert_true


def test_load_creative_items() raises:
    var br = vanilla_block_registry()
    var reg = vanilla_item_registry()
    var c = load_creative_items(br, reg)
    # The counts of interop/items' creative.txt.
    assert_equal(len(c.groups()), 124)
    assert_equal(len(c.items()), 1506)
    assert_equal(c.groups()[0].name, "itemGroup.name.planks")
    # Anonymous groups are named after their index.
    var anon = 0
    for ref g in c.groups():
        if g.name.startswith("anon"):
            anon += 1
    assert_true(anon > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
