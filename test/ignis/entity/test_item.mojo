from ignis.entity.item import (
    DEFAULT_PICKUP_DELAY_TICKS,
    EXISTENCE_DURATION_MS,
    ItemBehaviour,
)
from ignis.entity.register import VanillaEntities
from ignis.item.stack import Stack
from ignis.item.stick import Stick
from ignis.mgl64 import Vec3
from ignis.world.entity import EntityData, EntityHandle, EntitySpawnOpts
from minecraft.nbt.tree import Tree
from minecraft.protocol.uuid import UUID
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.world_runtime import new_item_world


def _item(pos: Vec3, delay: Int = 0) raises -> EntityHandle[VanillaEntities]:
    var opts = EntitySpawnOpts()
    opts.position = pos
    var nbt = Tree()
    _ = nbt.put_string(nbt.root(), "Name", "minecraft:stick")
    return EntityHandle[VanillaEntities](
        opts,
        VanillaEntities.wrap(ItemBehaviour(Stack(Stick(), 3), nbt^, delay)),
    )


def test_falls_onto_the_ground() raises:
    var w = new_item_world()
    var id = w.add_entity(_item(Vec3(0.5, -55, 0.5)))
    for _ in range(80):
        w.advance_tick()
    var h = w.entity(id).value().copy()
    # The flat world's grass top is at y = -61.
    assert_true(abs(h.data.pos.y() - -61) < 1e-6, String(h.data.pos))
    assert_equal(h.data.pos.x(), 0.5)
    assert_true(h.state[ItemBehaviour].mc.on_ground)
    assert_equal(h.data.vel.y(), 0)


def test_pickup_delay_counts_down() raises:
    var w = new_item_world()
    var id = w.add_entity(_item(Vec3(0.5, -61, 0.5)))
    assert_false(w.entity(id).value().state[ItemBehaviour].can_pick_up())
    for _ in range(DEFAULT_PICKUP_DELAY_TICKS):
        w.advance_tick()
    assert_true(w.entity(id).value().state[ItemBehaviour].can_pick_up())


def test_despawns_after_five_minutes() raises:
    var w = new_item_world()
    var h = _item(Vec3(0.5, -61, 0.5))
    h.data.age_ms = EXISTENCE_DURATION_MS + 50
    var id = w.add_entity(h^)
    w.advance_tick()
    assert_true(w.has_entity(id))
    w.advance_tick()
    assert_false(w.has_entity(id))


def test_nbt_round_trip() raises:
    var b = ItemBehaviour(Stack(Stick(), 3), Tree(), 25)
    _ = b.item_nbt.put_string(b.item_nbt.root(), "Name", "minecraft:stick")
    var t = Tree()
    var data = EntityData()
    b.encode_nbt(data, t, t.root())
    assert_equal(t.as_short(t.get(t.root(), "Health").value()), 5)
    var back = ItemBehaviour.decode_nbt(t, t.root(), data)
    assert_equal(back.pickup_delay_ticks, 25)
    assert_false(back.resolved())
    var name = back.item_nbt.get(back.item_nbt.root(), "Name").value()
    assert_equal(back.item_nbt.as_string(name), "minecraft:stick")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
