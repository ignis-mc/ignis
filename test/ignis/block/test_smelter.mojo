from ignis.block.blast_furnace import BlastFurnace
from ignis.block.cube.pos import Pos
from ignis.block.furnace import Furnace
from ignis.block.register import VanillaBlocks
from ignis.block.smelter import Smelter
from ignis.block.smoker import Smoker
from ignis.item.coal import Coal
from ignis.item.iron_ingot import IronIngot
from ignis.item.raw_iron import RawIron
from ignis.item.stack import Stack
from ignis.world.world import World
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.world_runtime import (
    RecordingViewer,
    VanillaWorld,
    new_vanilla_world,
)


def _load(mut w: World[VanillaWorld], pos: Pos, input: Int, fuel: Int) raises:
    var inv = w.inventory(pos).value().copy()
    inv.set_item(0, Stack(RawIron(), input))
    inv.set_item(1, Stack(Coal(), fuel))
    w.set_inventory(pos, inv^)


def test_smelter_nbt() raises:
    var s = Smelter()
    s.remaining_ms = 1500
    s.max_ms = 80000
    s.cook_ms = 250
    s.experience = 3
    var t = Tree()
    s.encode(t, t.root())
    assert_equal(t.get_short(t.root(), "BurnTime"), 30)
    assert_equal(t.get_short(t.root(), "BurnDuration"), 1600)
    assert_equal(t.get_short(t.root(), "CookTime"), 5)
    assert_true(Smelter.decode(t, t.root()) == s)


def test_furnace_smelts_in_ten_seconds() raises:
    var w = new_vanilla_world(items=True)
    var id = w.add_loader(0, RecordingViewer())
    w.load(id, 1000)
    var pos = Pos(1, -60, 1)
    w.set_block(pos, Furnace())
    _load(w, pos, 2, 1)
    w.advance_tick()
    # The coal is lit at once (Go: remaining = fuel duration, residue set).
    var f = w.block_as[Furnace](pos).value()
    assert_true(f.lit)
    assert_equal(w.inventory(pos).value().item(1).count(), 0)
    for _ in range(199):
        w.advance_tick()
    var inv = w.inventory(pos).value().copy()
    assert_equal(inv.item(0).count(), 1)
    assert_true(inv.item(2).item_as[IronIngot]())
    assert_equal(inv.item(2).count(), 1)
    # 200 ticks of 80 s of coal are used.
    var after = w.block_as[Furnace](pos).value()
    assert_equal(after.smelter.remaining_ms, 80000 - 200 * 50)
    assert_equal(after.smelter.cook_ms, 0)


def test_blast_furnace_twice_as_fast_on_ores() raises:
    var w = new_vanilla_world(items=True)
    var id = w.add_loader(0, RecordingViewer())
    w.load(id, 1000)
    var pos = Pos(1, -60, 1)
    w.set_block(pos, BlastFurnace())
    _load(w, pos, 1, 1)
    for _ in range(100):
        w.advance_tick()
    assert_equal(w.inventory(pos).value().item(2).count(), 1)


def test_smoker_ignores_ores() raises:
    var w = new_vanilla_world(items=True)
    var id = w.add_loader(0, RecordingViewer())
    w.load(id, 1000)
    var pos = Pos(1, -60, 1)
    w.set_block(pos, Smoker())
    _load(w, pos, 1, 1)
    for _ in range(5):
        w.advance_tick()
    # Raw iron is not food: nothing burns.
    assert_false(w.block_as[Smoker](pos).value().lit)
    assert_equal(w.inventory(pos).value().item(1).count(), 1)


def test_stored_experience_drops_when_broken() raises:
    var w = new_vanilla_world(items=True)
    var pos = Pos(1, -60, 1)
    var f = Furnace()
    f.smelter.experience = 5
    w.set_block(pos, f)
    var info = VanillaBlocks.break_info_at(Furnace.BASE_HASH, pos, w).value()
    assert_equal(info.xp_drops.min, 5)
    assert_equal(info.xp_drops.max, 5)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
