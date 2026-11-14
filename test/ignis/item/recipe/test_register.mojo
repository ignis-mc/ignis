from ignis.block.register import vanilla_block_registry
from ignis.item.recipe.recipe import RecipeKind
from ignis.item.recipe.register import hash_items
from ignis.item.recipe.vanilla import load_vanilla_recipes
from ignis.item.register import vanilla_item_registry
from ignis.world.item import EncodedItem
from std.testing import TestSuite, assert_equal, assert_false, assert_true


def test_hash_items_ignores_order() raises:
    var a: List[EncodedItem] = [
        EncodedItem("minecraft:b", 1),
        EncodedItem("minecraft:a", 2),
    ]
    var b: List[EncodedItem] = [
        EncodedItem("minecraft:a", 2),
        EncodedItem("minecraft:b", 1),
    ]
    assert_equal(hash_items(a.copy(), True), hash_items(b.copy(), True))
    assert_equal(hash_items(a.copy(), False), "minecraft:aminecraft:b")


def test_perform_brewing() raises:
    var br = vanilla_block_registry()
    var reg = vanilla_item_registry()
    var recipes = load_vanilla_recipes(br, reg)
    # Awkward potion (4) and a breeze rod give a wind charged potion (43).
    var input: List[EncodedItem] = [
        EncodedItem("minecraft:potion", 4),
        EncodedItem("minecraft:breeze_rod", 0),
    ]
    var out = recipes.perform("brewing_stand", input, reg)
    if reg.item_by_name("minecraft:breeze_rod", 0):
        assert_true(Bool(out))
    # A potion and gunpowder give a splash potion of the same type.
    var change: List[EncodedItem] = [
        EncodedItem("minecraft:potion", 5),
        EncodedItem("minecraft:gunpowder", 0),
    ]
    var splash = recipes.perform("brewing_stand", change, reg).value().copy()
    var enc = reg.encode_item(splash[0].item().value()).value()
    assert_equal(enc.name, "minecraft:splash_potion")
    assert_equal(enc.meta, 5)
    assert_true(
        recipes.valid_brewing_reagent(EncodedItem("minecraft:nether_wart", 0))
    )
    assert_false(recipes.valid_brewing_reagent(EncodedItem("minecraft:air", 0)))
    assert_false(Bool(recipes.perform("furnace", input, reg)))


def test_vanilla_counts() raises:
    var br = vanilla_block_registry()
    var reg = vanilla_item_registry()
    var recipes = load_vanilla_recipes(br, reg)
    var shaped = 0
    var multi = 0
    for ref r in recipes.recipes():
        if r.kind == RecipeKind.SHAPED:
            shaped += 1
        elif r.kind == RecipeKind.MULTI:
            multi += 1
    # The counts of interop/items' crafting.txt.
    assert_equal(shaped, 1007)
    assert_equal(multi, 14)
    assert_equal(len(recipes.dynamic_recipes()), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
