from ignis.block.air import Air
from ignis.block.bedrock import Bedrock
from ignis.block.dirt import Dirt
from ignis.block.grass import Grass
from ignis.block.register import vanilla_block_registry
from ignis.block.stone import Stone
from ignis.item.beef import Beef
from ignis.item.coal import Coal
from ignis.item.diamond import Diamond
from ignis.item.register import vanilla_item_registry
from ignis.item.shears import Shears
from ignis.item.stack import Stack
from ignis.item.stick import Stick
from ignis.session.item import stack_from_item, stack_to_item
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.item import ItemRegistry
from minecraft.nbt.decode import from_nbt
from minecraft.protocol.item import ItemStack, item
from minecraft.protocol.writer import Writer
from nethernet.wire import hex_encode
from std.collections import Dict
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.item_vectors import canonical, load_item_vectors


def _check(
    br: BasicBlockRegistry,
    reg: ItemRegistry,
    v: Dict[String, String],
    key: String,
    s: Stack,
) raises:
    var ps = stack_from_item(br, reg, s)
    var tree = from_nbt(ps.nbt_data)
    var got = String("{}")
    if not tree.is_empty():
        got = canonical(tree, tree.root())
    assert_equal(got, v["stack." + key + ".nbt"], key)
    if "stack." + key + ".bytes" in v:
        var w = Writer(0)
        item(w, ps)
        assert_equal(hex_encode(Span(w.take())), v["stack." + key + ".bytes"])


def test_stacks_match_dragonfly() raises:
    var br = vanilla_block_registry()
    var reg = vanilla_item_registry()
    var v = load_item_vectors()
    _check(br, reg, v, "stick", Stack(Stick(), 3))
    _check(br, reg, v, "diamond", Stack(Diamond(), 3))
    _check(br, reg, v, "coal", Stack(Coal(), 3))
    _check(br, reg, v, "beef", Stack(Beef(), 3))
    _check(br, reg, v, "cooked_beef", Stack(Beef(cooked=True), 3))
    _check(br, reg, v, "shears", Stack(Shears(), 3))
    _check(br, reg, v, "stone", Stack(Stone(), 3))
    _check(br, reg, v, "smooth_stone", Stack(Stone(smooth=True), 3))
    _check(br, reg, v, "grass", Stack(Grass(), 3))
    _check(br, reg, v, "dirt", Stack(Dirt(), 3))
    _check(br, reg, v, "coarse_dirt", Stack(Dirt(coarse=True), 3))
    _check(br, reg, v, "bedrock", Stack(Bedrock(), 3))
    _check(br, reg, v, "air", Stack(Air(), 1))
    _check(br, reg, v, "shears_damaged", Stack(Shears(), 1).damage(5))
    _check(
        br, reg, v, "shears_unbreakable", Stack(Shears(), 1).as_unbreakable()
    )
    _check(
        br, reg, v, "stick_named", Stack(Stick(), 64).with_custom_name("Wand")
    )
    _check(br, reg, v, "stick_lore", Stack(Stick(), 1).with_lore(["a", "b"]))
    _check(
        br,
        reg,
        v,
        "dirt_all",
        Stack(Dirt(), 2)
        .with_custom_name("Mud")
        .with_lore(["x"])
        .with_anvil_cost(3),
    )
    _check(
        br,
        reg,
        v,
        "shears_all",
        Stack(Shears(), 1).damage(237).with_custom_name("S").as_unbreakable(),
    )


def test_stack_round_trips() raises:
    var br = vanilla_block_registry()
    var reg = vanilla_item_registry()
    var stacks: List[Stack] = [
        Stack(Stick(), 64).with_custom_name("Wand").with_lore(["a", "b"]),
        Stack(Shears(), 1).damage(17).as_unbreakable(),
        Stack(Dirt(coarse=True), 5),
        Stack(Beef(cooked=True), 2),
        Stack(Grass(), 1),
    ]
    for s in stacks:
        var back = stack_to_item(br, reg, stack_from_item(br, reg, s))
        assert_true(back == s, String(s))
        assert_equal(back.custom_name(), s.custom_name())
        assert_equal(back.unbreakable(), s.unbreakable())
        assert_equal(back.durability(), s.durability())


def test_stack_to_item_block_runtime_id() raises:
    var br = vanilla_block_registry()
    var reg = vanilla_item_registry()
    # A block runtime ID decides the item, even for a state that is not
    # registered as an item (Go `b.(world.Item)`).
    var ps = ItemStack()
    ps.item_type.network_id = 7
    ps.count = 1
    ps.block_runtime_id = Int32(
        br.block_runtime_id(Bedrock(infinite_burning=True))
    )
    var s = stack_to_item(br, reg, ps)
    assert_true(s.item_as[Bedrock]().value() == Bedrock(infinite_burning=True))
    # Unknown items become air.
    var unknown = ItemStack()
    unknown.item_type.network_id = 30000
    unknown.count = 4
    assert_true(stack_to_item(br, reg, unknown).empty())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
