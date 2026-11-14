from ignis.block.cobblestone import Cobblestone
from ignis.block.hash import HASH_COBWEB, HASH_STONE
from ignis.item.axe import Axe
from ignis.item.diamond import Diamond
from ignis.item.hoe import Hoe
from ignis.item.pickaxe import Pickaxe
from ignis.item.shovel import Shovel
from ignis.item.stack import Stack
from ignis.item.sword import Sword
from ignis.item.tool import (
    TOOL_TIER_DIAMOND,
    TOOL_TIER_STONE,
    TOOL_TIER_WOOD,
    tool_tiers,
)
from ignis.world.item import AnyItem, ItemInfo, RegisteredItem
from std.testing import TestSuite, assert_equal, assert_true


def test_hash_round_trips() raises:
    for it in Pickaxe.all_items():
        assert_true(Pickaxe.from_hash(it.hash()) == it)
    for it in Axe.all_items():
        assert_true(Axe.from_hash(it.hash()) == it)
    for it in Shovel.all_items():
        assert_true(Shovel.from_hash(it.hash()) == it)
    for it in Sword.all_items():
        assert_true(Sword.from_hash(it.hash()) == it)
    for it in Hoe.all_items():
        assert_true(Hoe.from_hash(it.hash()) == it)
    assert_equal(len(Pickaxe.all_items()), len(tool_tiers()))


def test_sword_efficiency() raises:
    var s = Sword(tier=TOOL_TIER_DIAMOND)
    assert_equal(s.base_mining_efficiency(HASH_COBWEB), 15.0)
    assert_equal(s.base_mining_efficiency(HASH_STONE), 1.5)


def _block_stack(c: Cobblestone) -> Stack:
    # Cobblestone becomes an item with the block item port; wrap it by hand.
    var it = AnyItem(Cobblestone.BASE_HASH, c.hash(), True)
    return Stack(RegisteredItem(it, ItemInfo()), 1)


def test_repair() raises:
    var stone = Pickaxe(tier=TOOL_TIER_STONE)
    assert_true(stone.repairable_by(_block_stack(Cobblestone())))
    assert_true(not stone.repairable_by(_block_stack(Cobblestone(mossy=True))))
    assert_true(
        Pickaxe(tier=TOOL_TIER_DIAMOND).repairable_by(Stack(Diamond(), 1))
    )
    assert_true(
        not Pickaxe(tier=TOOL_TIER_WOOD).repairable_by(Stack(Diamond(), 1))
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
