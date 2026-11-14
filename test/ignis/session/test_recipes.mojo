from ignis.block.register import vanilla_block_registry
from ignis.item.recipe.vanilla import load_vanilla_recipes
from ignis.item.register import vanilla_item_registry
from ignis.session.recipes import crafting_data, random_recipe_ids
from minecraft.nbt.decode import from_nbt
from minecraft.nbt.encode import to_nbt
from minecraft.nbt.nbt import LITTLE_ENDIAN
from minecraft.protocol.item import ItemStack
from minecraft.protocol.item_descriptor import (
    DefaultItemDescriptor,
    ItemDescriptorCount,
    ItemTagItemDescriptor,
)
from minecraft.protocol.writer import Writer
from std.testing import TestSuite, assert_equal, assert_true
from support.item_vectors import canonical, sorted_tree


def _stack(s: ItemStack) raises -> String:
    var n = String("{}")
    if len(s.nbt_data.raw) != 0:
        var t = from_nbt(s.nbt_data)
        n = canonical(t, t.root())
    return String(
        t"{s.item_type.network_id}:{s.item_type.metadata_value}*{s.count}"
        t" {s.block_runtime_id} {n}"
    )


def _stacks(l: List[ItemStack]) raises -> String:
    var parts = List[String]()
    for s in l:
        parts.append(_stack(s))
    return String(",").join(parts)


def _descriptor(d: ItemDescriptorCount) -> String:
    if d.descriptor.value.isa[DefaultItemDescriptor]():
        ref x = d.descriptor.value[DefaultItemDescriptor]
        return String(t"{x.name}:{x.metadata_value}*{d.count}")
    if d.descriptor.value.isa[ItemTagItemDescriptor]():
        ref x = d.descriptor.value[ItemTagItemDescriptor]
        return String(t"#{x.tag}*{d.count}")
    return String(t"-*{d.count}")


def _descriptors(l: List[ItemDescriptorCount]) -> String:
    var parts = List[String]()
    for d in l:
        parts.append(_descriptor(d))
    return String(",").join(parts)


def _sorted(var s: ItemStack) raises -> ItemStack:
    if len(s.nbt_data.raw) != 0:
        s.nbt_data = to_nbt(sorted_tree(from_nbt(s.nbt_data)), LITTLE_ENDIAN)
    return s^


def test_crafting_data_matches_dragonfly() raises:
    """The CraftingData packet holds the recipes Dragonfly sends
    (`crafting.txt` from `interop/items`) and, with empty recipe IDs and
    NBT keys sorted, has the same bytes (`crafting_data.bin`)."""
    var br = vanilla_block_registry()
    var reg = vanilla_item_registry()
    var recipes = load_vanilla_recipes(br, reg)
    var ids = List[String]()
    for _ in range(len(recipes.recipes())):
        ids.append(String())
    var pk = crafting_data(br, reg, recipes, ids)
    var got = List[String]()
    for ref r in pk.shaped_recipes:
        got.append(
            String(
                t"shaped\t{r.recipe_network_id}\t{r.priority}\t{r.block}\t"
                t"{r.width}x{r.height}\t{_descriptors(r.input)}\t"
                t"{_stacks(r.output)}"
            )
        )
    for ref r in pk.shapeless_recipes:
        got.append(
            String(
                t"shapeless\t{r.recipe_network_id}\t{r.priority}\t{r.block}\t"
                t"{_descriptors(r.input)}\t{_stacks(r.output)}"
            )
        )
    for ref r in pk.multi_recipes:
        got.append(String(t"multi\t{r.recipe_network_id}\t{r.uuid}"))
    for ref r in pk.user_data_shapeless_recipes:
        got.append(
            String(
                t"userdata\t{r.recipe_network_id}\t{r.priority}\t{r.block}\t"
                t"{_descriptors(r.input)}\t{_stacks(r.output)}"
            )
        )
    for ref r in pk.smithing_transform_recipes:
        var d: List[ItemDescriptorCount] = [
            r.template.copy(),
            r.base.copy(),
            r.addition.copy(),
        ]
        got.append(
            String(
                t"smithing\t{r.recipe_network_id}\t{r.block}\t"
                t"{_descriptors(d)}\t{_stack(r.result)}"
            )
        )
    for ref r in pk.smithing_trim_recipes:
        var d: List[ItemDescriptorCount] = [
            r.template.copy(),
            r.base.copy(),
            r.addition.copy(),
        ]
        got.append(
            String(t"trim\t{r.recipe_network_id}\t{r.block}\t{_descriptors(d)}")
        )
    for ref r in pk.potion_recipes:
        got.append(
            String(
                t"potion\t{r.input_potion_id}:{r.input_potion_metadata}\t"
                t"{r.reagent_item_id}:{r.reagent_item_metadata}\t"
                t"{r.output_potion_id}:{r.output_potion_metadata}"
            )
        )
    for ref r in pk.potion_container_change_recipes:
        got.append(
            String(
                t"container\t{r.input_item_id}\t{r.reagent_item_id}\t"
                t"{r.output_item_id}"
            )
        )
    var want = List[String]()
    with open("test/data/items/crafting.txt", "r") as f:
        for line in f.read().split("\n"):
            if line.byte_length() != 0:
                want.append(String(line))
    var mismatches = 0
    for i in range(min(len(got), len(want))):
        if got[i] != want[i]:
            mismatches += 1
            if mismatches <= 10:
                print("want:", want[i])
                print("got: ", got[i])
    assert_equal(len(got), len(want), "recipe count")
    assert_equal(mismatches, 0, "every recipe matches Dragonfly")

    for ref r in pk.shaped_recipes:
        for ref s in r.output:
            s = _sorted(s.copy())
    for ref r in pk.shapeless_recipes:
        for ref s in r.output:
            s = _sorted(s.copy())
    for ref r in pk.user_data_shapeless_recipes:
        for ref s in r.output:
            s = _sorted(s.copy())
    for ref r in pk.smithing_transform_recipes:
        r.result = _sorted(r.result.copy())
    var w = Writer(0)
    pk.marshal(w)
    var bytes = w.take()
    var expected: List[UInt8]
    with open("test/data/items/crafting_data.bin", "r") as f:
        expected = f.read_bytes()
    assert_equal(len(bytes), len(expected))
    assert_true(bytes == expected, "CraftingData bytes match")


def test_random_recipe_ids() raises:
    var ids = random_recipe_ids(2)
    assert_equal(ids[0].byte_length(), 36)
    assert_true(ids[0] != ids[1])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
