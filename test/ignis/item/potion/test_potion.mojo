from ignis.entity.effect import SECOND
from ignis.item.potion.potion import Potion, all_potions, from_id
from std.testing import TestSuite, assert_equal, assert_true


def test_all_potions() raises:
    var all = all_potions()
    assert_equal(len(all), 43)
    for i in range(len(all)):
        assert_equal(Int(all[i].uint8()), i)
    assert_true(all[42] == Potion.STRONG_SLOWNESS)
    assert_true(from_id(21) == Potion.HEALING)


def test_effects() raises:
    assert_equal(len(Potion.WATER.effects()), 0)
    assert_equal(len(Potion.AWKWARD.effects()), 0)
    var e = Potion.STRONG_POISON.effects()
    assert_equal(len(e), 1)
    assert_equal(e[0].type_id(), 19)
    assert_equal(e[0].level(), 2)
    assert_equal(e[0].duration(), 22500 * SECOND // 1000)
    var heal = Potion.STRONG_HEALING.effects()
    assert_equal(heal[0].type_id(), 6)
    assert_true(not heal[0].lasting())
    var turtle = Potion.STRONG_TURTLE_MASTER.effects()
    assert_equal(len(turtle), 2)
    assert_equal(turtle[0].type_id(), 11)
    assert_equal(turtle[0].level(), 5)
    assert_equal(turtle[1].level(), 6)
    assert_equal(turtle[1].duration(), 20 * SECOND)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
