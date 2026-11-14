from ignis.block.chest import Chest
from ignis.block.cube.direction import Direction
from ignis.block.cube.pos import Pos
from ignis.block.stone import Stone
from ignis.item.diamond import Diamond
from ignis.item.stack import Stack
from ignis.item.stick import Stick
from ignis.world.position import ChunkPos
from ignis.world.world import World
from minecraft.nbt.nbt import TAG_LIST
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_true,
)
from support.world_runtime import (
    RecordingViewer,
    VanillaWorld,
    new_vanilla_world,
)


def _viewing(mut w: World[VanillaWorld]) -> UInt64:
    var id = w.add_loader(0, RecordingViewer())
    w.load(id, 1000)
    return id


def test_nbt_blocks_get_a_block_entity() raises:
    var w = new_vanilla_world(items=True)
    var id = _viewing(w)
    var pos = Pos(1, -60, 1)
    w.set_block(pos, Chest(facing=Direction.EAST, custom_name="Loot"))
    var nbt = w.block_entity_nbt(pos)
    assert_true(nbt)
    assert_equal(nbt.value().get_string(nbt.value().root(), "id"), "Chest")
    # The block comes back with the fields its NBT holds.
    var c = w.block_as[Chest](pos).value()
    assert_equal(c.custom_name, "Loot")
    assert_true(c.facing == Direction.EAST)
    assert_equal(w.inventory(pos).value().size(), 27)
    assert_equal(w.viewer(id).count("block_entity"), 1)
    # A block without NBT drops the entity.
    w.set_block(pos, Stone())
    assert_false(w.block_entity_nbt(pos))
    assert_false(w.inventory(pos))


def test_same_type_keeps_the_inventory() raises:
    var w = new_vanilla_world(items=True)
    var pos = Pos(2, -60, 2)
    w.set_block(pos, Chest())
    var inv = w.inventory(pos).value().copy()
    inv.set_item(3, Stack(Diamond(), 5))
    w.set_inventory(pos, inv^)
    # Turning the chest keeps what it holds, as Go keeps the pointer.
    w.set_block(pos, Chest(facing=Direction.WEST))
    assert_equal(w.inventory(pos).value().item(3).count(), 5)
    assert_true(w.block_as[Chest](pos).value().facing == Direction.WEST)


def test_viewers_see_slot_changes() raises:
    var w = new_vanilla_world(items=True)
    var a = _viewing(w)
    var b = _viewing(w)
    var pos = Pos(3, -60, 3)
    w.set_block(pos, Chest())
    assert_equal(w.add_container_viewer(pos, a), 0)
    assert_equal(w.add_container_viewer(pos, b), 1)
    assert_equal(w.add_container_viewer(pos, b), 2)
    var inv = w.inventory(pos).value().copy()
    inv.set_item(0, Stack(Stick(), 7))
    w.set_inventory(pos, inv^)
    w.flush_container_changes(exclude=a)
    assert_equal(w.viewer(a).count("slot"), 0)
    assert_equal(w.viewer(b).count("slot 0 7"), 1)
    # The right half of a paired chest shows its slots after 27.
    w.set_viewer_slot_offset(pos, 27)
    inv = w.inventory(pos).value().copy()
    inv.set_item(1, Stack(Stick(), 2))
    w.set_inventory(pos, inv^)
    w.flush_container_changes()
    assert_equal(w.viewer(a).count("slot 28 2"), 1)
    assert_equal(w.remove_container_viewer(pos, a), 1)
    assert_equal(w.remove_container_viewer(pos, a), -1)
    # Breaking the chest closes the window of who still looks at it.
    w.set_block(pos, Stone())
    assert_equal(w.viewer(b).count("container_removed"), 1)


def test_contents_survive_a_reload() raises:
    var w = new_vanilla_world(items=True)
    var id = _viewing(w)
    var pos = Pos(4, -60, 4)
    w.set_block(pos, Chest(custom_name="Kept"))
    var inv = w.inventory(pos).value().copy()
    inv.set_item(26, Stack(Diamond(), 12))
    w.set_inventory(pos, inv^)
    _ = w.close_loader(id)
    w.close_unused_chunks()
    assert_equal(len(w.loaded_chunks()), 0)
    var col = (
        w.provider().load_column(ChunkPos(0, 0), w.dimension()).value().copy()
    )
    assert_equal(len(col.block_entities), 1)
    ref t = col.block_entities[0].data
    assert_equal(t.get_int(t.root(), "x"), 4)
    assert_equal(t.get_int(t.root(), "y"), -60)
    var items = t.get_list(t.root(), "Items")
    assert_equal(t.type_of(items), TAG_LIST)
    assert_equal(t.length(items), 1)
    assert_equal(t.get_byte(t.at(items, 0), "Slot"), 26)
    assert_equal(t.get_byte(t.at(items, 0), "Count"), 12)
    # Loading the chunk again restores the chest and its contents.
    var c = w.block_as[Chest](pos).value()
    assert_equal(c.custom_name, "Kept")
    var back = w.inventory(pos).value().copy()
    assert_true(back.item(26).item_as[Diamond]())
    assert_equal(back.item(26).count(), 12)


def test_network_block_entities_per_sub_chunk() raises:
    var w = new_vanilla_world(items=True)
    var id = _viewing(w)
    w.set_block(Pos(5, -60, 5), Chest())
    w.set_block(Pos(5, 10, 5), Chest())
    # The flat world spans -64..319: -60 is in sub-chunk 0, 10 in 4.
    assert_equal(len(w.network_block_entities(ChunkPos(0, 0), 0)), 1)
    assert_equal(len(w.network_block_entities(ChunkPos(0, 0), 4)), 1)
    assert_equal(len(w.network_block_entities(ChunkPos(0, 0), 1)), 0)
    var t = w.network_block_entities(ChunkPos(0, 0), 4)[0].copy()
    assert_equal(t.get_int(t.root(), "y"), 10)
    _ = id


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
