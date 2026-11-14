from ignis.block.block import UseContext, User
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.cube.rotation import Rotation
from ignis.block.register import VanillaBlocks
from ignis.block.shulker_box import ShulkerBox
from ignis.block.stone import Stone
from ignis.item.diamond import Diamond
from ignis.item.optional_colour import OptionalColour
from ignis.item.stack import Stack
from ignis.mgl64 import Vec3
from minecraft.nbt.nbt import TAG_END
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.world_runtime import new_vanilla_world


def test_shulker_box_item() raises:
    assert_equal(
        ShulkerBox().encode_item().name, "minecraft:undyed_shulker_box"
    )
    assert_equal(ShulkerBox().max_count(), 1)
    assert_equal(len(ShulkerBox.all_items()), 17)


def test_shulker_box_nbt_round_trip() raises:
    var tag = Tree()
    var r = tag.root()
    ShulkerBox(facing=Face.EAST, custom_name="Loot").encode_nbt(tag, r)
    assert_equal(tag.get_string(r, "id"), "ShulkerBox")
    assert_equal(tag.length(tag.get_list(r, "Items")), 0)
    assert_equal(tag.elem_type(tag.get_list(r, "Items")), TAG_END)
    assert_equal(Int(tag.get_byte(r, "facing")), Int(Face.EAST))
    var back = ShulkerBox().decode_nbt(tag, r)
    assert_equal(Int(back.facing), Int(Face.EAST))
    assert_equal(back.custom_name, "Loot")
    # No custom name: no CustomName key, as in Go.
    var plain = Tree()
    ShulkerBox().encode_nbt(plain, plain.root())
    assert_equal(plain.has(plain.root(), "CustomName"), False)


def test_breaking_keeps_the_contents_in_the_item() raises:
    var w = new_vanilla_world(items=True)
    var pos = Pos(3, -60, 3)
    w.set_block(pos, ShulkerBox(facing=Face.UP))
    var inv = w.inventory(pos).value().copy()
    inv.set_item(4, Stack(Diamond(), 9))
    w.set_inventory(pos, inv^)
    VanillaBlocks.handle_break(ShulkerBox.BASE_HASH, pos, w, True)
    var drops = w.take_item_drops()
    assert_equal(len(drops), 1)
    var it = drops[0].stack.copy()
    assert_true(it.item_as[ShulkerBox]())
    var nbt = it.item_nbt()
    var items = nbt.get_list(nbt.root(), "Items")
    assert_equal(nbt.length(items), 1)
    assert_equal(nbt.get_byte(nbt.at(items, 0), "Count"), 9)
    # Placing it again brings the diamonds back.
    w.set_block(pos, Stone())
    var at = Pos(5, -60, 5)
    var user = User(Rotation(), Vec3(), 1.62, it)
    var list = ShulkerBox().use_on_block(at, Face.NORTH, Vec3(), user, w)
    assert_equal(len(list), 1)
    assert_true(list[0].contents)
    var br = w.block_registry()
    var rid = br[].runtime_id_of(list[0].block.kind, list[0].block.state)
    w.set_block_runtime_id(at, rid.value())
    w.set_block_entity_nbt(at, list[0].nbt.value().copy(), True)
    var back = w.inventory(at).value().copy()
    assert_equal(back.item(4).count(), 9)
    assert_equal(
        Int(w.block_as[ShulkerBox](at).value().facing), Int(Face.NORTH)
    )


def test_creative_breaking_drops_nothing() raises:
    var w = new_vanilla_world(items=True)
    var pos = Pos(3, -60, 3)
    w.set_block(pos, ShulkerBox())
    VanillaBlocks.handle_break(ShulkerBox.BASE_HASH, pos, w, False)
    assert_equal(len(w.take_item_drops()), 0)


def test_opens_with_room_for_the_lid() raises:
    var w = new_vanilla_world(items=True)
    var pos = Pos(3, -60, 3)
    w.set_block(pos, ShulkerBox(facing=Face.UP))
    var ctx = UseContext()
    assert_true(
        VanillaBlocks.activate(ShulkerBox.BASE_HASH, pos, Face.UP, w, ctx)
    )
    assert_true(ctx.open_container)
    w.set_block(pos.side(Face.UP), Stone())
    var shut = UseContext()
    _ = VanillaBlocks.activate(ShulkerBox.BASE_HASH, pos, Face.UP, w, shut)
    assert_false(shut.open_container)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
