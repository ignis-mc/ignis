from ignis.block.chest import Chest
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.furnace import Furnace
from ignis.block.hopper import Hopper
from ignis.entity.item import ItemBehaviour
from ignis.entity.register import VanillaEntities
from ignis.item.coal import Coal
from ignis.item.raw_iron import RawIron
from ignis.item.stack import Stack
from ignis.item.stick import Stick
from ignis.mgl64 import Vec3
from ignis.world.entity import EntityHandle, EntitySpawnOpts
from ignis.world.world import World
from minecraft.nbt.nbt import TAG_END
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.world_runtime import (
    RecordingViewer,
    VanillaWorld,
    new_vanilla_world,
)


def _world() raises -> World[VanillaWorld]:
    var w = new_vanilla_world(items=True)
    var id = w.add_loader(0, RecordingViewer())
    w.load(id, 1000)
    return w^


def _put(mut w: World[VanillaWorld], pos: Pos, slot: Int, s: Stack) raises:
    var inv = w.inventory(pos).value().copy()
    inv.set_item(slot, s)
    w.set_inventory(pos, inv^)


def _count(mut w: World[VanillaWorld], pos: Pos) raises -> Int:
    var n = 0
    var inv = w.inventory(pos).value().copy()
    for i in range(inv.size()):
        n += inv.item(i).count()
    return n


def test_nbt_round_trip() raises:
    var h = Hopper(facing=Face.NORTH, custom_name="Sorter", transfer_cooldown=4)
    var t = Tree()
    h.encode_nbt(t, t.root())
    var items = t.get_list(t.root(), "Items")
    assert_equal(t.length(items), 0)
    assert_equal(t.elem_type(items), TAG_END)
    assert_equal(t.get_int(t.root(), "TransferCooldown"), 4)
    assert_equal(t.get_string(t.root(), "CustomName"), "Sorter")
    var back = Hopper(facing=Face.NORTH).decode_nbt(t, t.root())
    assert_true(back == h)
    assert_equal(back.custom_name, "Sorter")
    assert_equal(back.transfer_cooldown, 4)


def test_no_custom_name_key_when_unnamed() raises:
    var t = Tree()
    Hopper().encode_nbt(t, t.root())
    assert_false(t.has(t.root(), "CustomName"))


def test_moves_one_item_every_eight_ticks() raises:
    var w = _world()
    var top = Pos(2, -58, 2)
    var mid = Pos(2, -59, 2)
    var bottom = Pos(2, -60, 2)
    w.set_block(top, Chest())
    w.set_block(mid, Hopper(facing=Face.DOWN))
    w.set_block(bottom, Chest())
    _put(w, top, 0, Stack(Stick(), 3))
    w.advance_tick()
    # The first tick pulls one stick in; pushing waits for the next round.
    assert_equal(_count(w, top), 2)
    assert_equal(_count(w, mid), 1)
    for _ in range(8):
        w.advance_tick()
    assert_equal(_count(w, bottom), 1)
    assert_equal(_count(w, top), 1)
    for _ in range(16):
        w.advance_tick()
    assert_equal(_count(w, bottom), 3)
    assert_equal(_count(w, mid), 0)


def test_feeds_a_furnace_by_side() raises:
    var w = _world()
    var furnace = Pos(4, -60, 4)
    w.set_block(furnace, Furnace())
    # From above, the input; from the side, the fuel (Go `InsertItem`).
    w.set_block(Pos(4, -59, 4), Hopper(facing=Face.DOWN))
    w.set_block(Pos(5, -60, 4), Hopper(facing=Face.WEST))
    _put(w, Pos(4, -59, 4), 0, Stack(RawIron(), 1))
    _put(w, Pos(5, -60, 4), 0, Stack(RawIron(), 1))
    _put(w, Pos(5, -60, 4), 1, Stack(Coal(), 1))
    w.advance_tick()
    var inv = w.inventory(furnace).value().copy()
    assert_true(inv.item(0).item_as[RawIron]())
    # Raw iron is no fuel, so the side hopper sends its coal. Whether the
    # furnace ticked after it and burnt the coal already depends on the
    # order block entities tick in (Go: map order).
    var f = w.block_as[Furnace](furnace).value()
    if f.lit:
        assert_equal(f.smelter.max_ms, 80000)
    else:
        assert_true(inv.item(1).item_as[Coal]())
    assert_equal(_count(w, Pos(5, -60, 4)), 1)


def test_collects_item_entities() raises:
    var w = _world()
    var pos = Pos(6, -60, 6)
    w.set_block(pos, Hopper())
    var opts = EntitySpawnOpts()
    opts.position = Vec3(6.5, -59, 6.5)
    var nbt = Tree()
    var h = EntityHandle[VanillaEntities](
        opts, VanillaEntities.wrap(ItemBehaviour(Stack(Stick(), 5), nbt^, 1))
    )
    var id = w.add_entity(h^)
    w.advance_tick()
    assert_false(w.has_entity(id))
    assert_equal(_count(w, pos), 5)
    # Set to 8 by the item, then counted down by the hopper's own tick in
    # the same world tick (Go ticks entities before block entities).
    assert_equal(w.block_as[Hopper](pos).value().collect_cooldown, 7)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
