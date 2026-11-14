from ignis.block.air import Air
from ignis.block.bookshelf import Bookshelf
from ignis.block.cube.pos import Pos
from ignis.block.enchanting_table import EnchantingTable
from ignis.item.armour import ArmourTier
from ignis.item.book import Book
from ignis.item.bow import Bow
from ignis.item.helmet import Helmet
from ignis.item.pickaxe import Pickaxe
from ignis.item.stack import Stack
from ignis.item.sword import Sword
from ignis.item.tool import TOOL_TIER_DIAMOND, TOOL_TIER_IRON
from ignis.session.enchanting import offers_for, search_bookshelves
from std.testing import TestSuite, assert_equal
from support.world_runtime import new_vanilla_world


def _item(name: String) -> Stack:
    if name == "diamond_pickaxe":
        return Stack(Pickaxe(tier=TOOL_TIER_DIAMOND), 1)
    if name == "iron_sword":
        return Stack(Sword(tier=TOOL_TIER_IRON), 1)
    if name == "diamond_helmet":
        return Stack(Helmet(tier=ArmourTier.DIAMOND), 1)
    if name == "bow":
        return Stack(Bow(), 1)
    return Stack(Book(), 1)


def _format(s: Stack, seed: Int64, shelves: Int) -> String:
    var o = offers_for(s, seed, shelves).value().copy()
    var out = String()
    for i in range(3):
        if i > 0:
            out += " "
        out += String(o.costs[i]) + "="
        for j in range(len(o.enchants[i])):
            if j > 0:
                out += ","
            ref e = o.enchants[i][j]
            out += String(e.id) + ":" + String(e.level)
    return out^


def test_offers_match_dragonfly() raises:
    # test/data/enchanting/vectors.txt comes from interop/enchanting, which
    # runs Dragonfly's offer code with its enchantment data.
    var text: String
    with open("test/data/enchanting/vectors.txt", "r") as f:
        text = f.read()
    var n = 0
    for line in text.splitlines():
        if line.byte_length() == 0:
            continue
        var parts = line.split(" ", 3)
        var seed = Int64(atol(parts[0]))
        var shelves = atol(parts[1])
        var want = String(parts[3])
        var got = _format(_item(String(parts[2])), seed, shelves)
        if got != want:
            raise Error(t"{line}: got {got}")
        n += 1
    assert_equal(n, 60)


def test_bookshelves_need_air_between() raises:
    var w = new_vanilla_world()
    var t = Pos(0, -60, 0)
    w.set_block(t, EnchantingTable())
    w.set_block(Pos(2, -60, 0), Bookshelf())
    w.set_block(Pos(2, -59, 1), Bookshelf())
    w.set_block(Pos(-2, -60, -2), Bookshelf())
    assert_equal(search_bookshelves(w, t), 3)
    # A block between the table and a shelf takes its power away.
    w.set_block(Pos(1, -60, 0), Bookshelf())
    assert_equal(search_bookshelves(w, t), 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
