from ignis.block.air import Air
from ignis.block.dirt import Dirt
from ignis.item.beef import Beef
from ignis.item.shears import Shears
from ignis.item.stack import Enchantment, Stack
from ignis.item.stick import Stick
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.item_vectors import load_item_vectors


def test_empty() raises:
    assert_true(Stack().empty())
    assert_true(Stack(Air(), 5).empty())
    assert_true(Stack(Stick(), 0).empty())
    assert_false(Stack(Stick(), 1).empty())
    assert_false(Stack().item())
    assert_true(Stack(Stick(), 1).item_as[Stick]())
    assert_false(Stack(Stick(), 1).item_as[Beef]())


def test_count() raises:
    var s = Stack(Stick(), 10)
    assert_equal(s.count(), 10)
    assert_equal(s.max_count(), 64)
    assert_equal(s.grow(5).count(), 15)
    assert_equal(s.grow(-50).count(), 0)
    assert_equal(Stack(Shears(), 1).max_count(), 1)


def test_durability_matches_dragonfly() raises:
    var v = load_item_vectors()
    var s = Stack(Shears(), 1)
    assert_equal(s.durability(), 238)
    assert_equal(s.max_durability(), 238)
    assert_equal(
        String(s.damage(5).durability()), v["durability.shears.after_damage_5"]
    )
    assert_equal(
        String(s.damage(238).count()), v["durability.shears.after_break"]
    )
    assert_true(s.damage(238).empty())
    # Repairing past the maximum gives full durability.
    assert_equal(s.damage(5).damage(-50).durability(), 238)
    # Unbreakable stacks take no damage.
    assert_equal(s.as_unbreakable().damage(100).durability(), 238)
    assert_false(s.as_unbreakable().as_breakable().unbreakable())
    assert_equal(s.with_durability(10).durability(), 10)
    assert_equal(s.with_durability(1000).durability(), 238)
    assert_true(s.with_durability(0).empty())
    # Items without durability ignore all of it.
    var stick = Stack(Stick(), 3)
    assert_equal(stick.durability(), -1)
    assert_equal(stick.max_durability(), -1)
    assert_true(stick.damage(5) == stick)
    assert_false(stick.as_unbreakable().unbreakable())


def test_names_and_lore() raises:
    var s = Stack(Stick(), 1).with_custom_name("Wand").with_lore(["a", "b"])
    assert_equal(s.custom_name(), "Wand")
    assert_equal(len(s.lore()), 2)
    assert_equal(len(Stack(Air(), 1).with_lore(["x"]).lore()), 0)


def test_anvil_cost() raises:
    # Only repairable items take an anvil cost (Go `WithAnvilCost`).
    assert_equal(Stack(Dirt(), 1).with_anvil_cost(3).anvil_cost(), 0)
    assert_equal(Stack(Shears(), 1).with_anvil_cost(3).anvil_cost(), 0)


def test_enchantments() raises:
    var s = Stack(Shears(), 1).with_forced_enchantments(
        [Enchantment(17, 3), Enchantment(15, 1), Enchantment(17, 2)]
    )
    var e = s.enchantments()
    assert_equal(len(e), 2)
    assert_equal(e[0].id, 15)
    assert_equal(e[1].id, 17)
    assert_equal(e[1].level, 2)
    assert_equal(s.enchantment(17).value().level, 2)
    assert_false(s.without_enchantments([17]).enchantment(17))


def test_comparable_and_equal() raises:
    var a = Stack(Stick(), 3)
    assert_true(a.comparable(Stack(Stick(), 60)))
    assert_false(a.comparable(Stack(Beef(), 3)))
    assert_false(a.comparable(a.with_custom_name("x")))
    assert_true(a.comparable(Stack()))
    assert_true(a == Stack(Stick(), 3))
    assert_false(a == Stack(Stick(), 4))
    assert_false(Stack(Beef(), 1) == Stack(Beef(cooked=True), 1))


def test_add_stack() raises:
    var r = Stack(Stick(), 60).add_stack(Stack(Stick(), 10))
    assert_equal(r[0].count(), 64)
    assert_equal(r[1].count(), 6)
    var other = Stack(Stick(), 1).add_stack(Stack(Beef(), 10))
    assert_equal(other[0].count(), 1)
    assert_equal(other[1].count(), 10)


def test_id() raises:
    assert_equal(Stack(Stick(), 1).id(), 0)
    assert_equal(Stack(Stick(), 1).with_id(9).id(), 9)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
