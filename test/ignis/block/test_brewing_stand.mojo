from ignis.block.brewing_stand import BrewingStand
from ignis.block.cube.pos import Pos
from ignis.block.nether_wart import NetherWart
from ignis.item.blaze_powder import BlazePowder
from ignis.item.potion import Potion
from ignis.item.potion.potion import Potion as PotionType
from ignis.item.recipe.vanilla import load_vanilla_recipes
from ignis.item.stack import Stack
from ignis.world.world import World
from std.memory import ArcPointer
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.world_runtime import (
    RecordingViewer,
    VanillaWorld,
    new_vanilla_world,
)


def _world() raises -> World[VanillaWorld]:
    var w = new_vanilla_world(items=True)
    w.set_recipes(
        ArcPointer(
            load_vanilla_recipes(w.block_registry()[], w.item_registry()[])
        )
    )
    var id = w.add_loader(0, RecordingViewer())
    w.load(id, 1000)
    return w^


def test_nether_wart_makes_awkward_potions() raises:
    var w = _world()
    var pos = Pos(1, -60, 1)
    w.set_block(pos, BrewingStand())
    var inv = w.inventory(pos).value().copy()
    inv.set_item(0, Stack(NetherWart(), 2))
    inv.set_item(1, Stack(Potion(type=PotionType.WATER), 1))
    inv.set_item(3, Stack(Potion(type=PotionType.WATER), 1))
    inv.set_item(4, Stack(BlazePowder(), 1))
    w.set_inventory(pos, inv^)
    w.advance_tick()
    # Blaze powder gives 20 brews; the bottle slots show on the block.
    var b = w.block_as[BrewingStand](pos).value()
    assert_equal(b.brewer.fuel_amount, 20)
    assert_true(b.left_slot and not b.middle_slot and b.right_slot)
    for _ in range(399):
        w.advance_tick()
    var out = w.inventory(pos).value().copy()
    assert_true(
        out.item(1).item_as[Potion]().value().type == PotionType.AWKWARD
    )
    assert_true(
        out.item(3).item_as[Potion]().value().type == PotionType.AWKWARD
    )
    assert_equal(out.item(0).count(), 1)
    assert_true(out.item(4).empty())
    assert_equal(w.block_as[BrewingStand](pos).value().brewer.fuel_amount, 19)


def test_no_brewing_without_fuel() raises:
    var w = _world()
    var pos = Pos(1, -60, 1)
    w.set_block(pos, BrewingStand())
    var inv = w.inventory(pos).value().copy()
    inv.set_item(0, Stack(NetherWart(), 1))
    inv.set_item(2, Stack(Potion(type=PotionType.WATER), 1))
    w.set_inventory(pos, inv^)
    for _ in range(5):
        w.advance_tick()
    var b = w.block_as[BrewingStand](pos).value()
    assert_equal(b.brewer.duration_ms, 0)
    assert_false(w.inventory(pos).value().item(0).empty())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
