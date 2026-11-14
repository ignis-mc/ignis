from ignis.item.inventory.inventory import Inventory
from ignis.item.diamond import Diamond
from ignis.item.shears import Shears
from ignis.item.stack import Stack
from ignis.item.stick import Stick
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)


def test_add_fills_comparable_then_empty() raises:
    var inv = Inventory(3)
    inv.set_item(1, Stack(Stick(), 60))
    assert_equal(inv.add_item(Stack(Stick(), 10)), 10)
    # Slot 1 is topped up to 64, the remaining 6 go to the first empty slot.
    assert_equal(inv.item(1).count(), 64)
    assert_equal(inv.item(0).count(), 6)
    assert_true(inv.item(2).empty())


def test_add_when_full() raises:
    var inv = Inventory(1)
    inv.set_item(0, Stack(Diamond(), 60))
    assert_equal(inv.add_item(Stack(Diamond(), 10)), 4)
    assert_equal(inv.add_item(Stack(Stick(), 1)), 0)


def test_set_caps_and_assigns_ids() raises:
    var inv = Inventory(2)
    inv.set_item(0, Stack(Shears(), 5))
    assert_equal(inv.item(0).count(), 1)
    var a = inv.item(0).id()
    inv.set_item(1, Stack(Stick(), 1))
    assert_true(a > 0)
    assert_equal(inv.item(1).id(), a + 1)
    # A stack that keeps its ID (a swap) keeps it.
    inv.swap(0, 1)
    assert_equal(inv.item(1).id(), a)
    assert_equal(inv.take_changes(), [0, 1])
    assert_equal(len(inv.take_changes()), 0)
    # An emptied slot holds the zero stack, ID 0.
    inv.set_item(0, inv.item(0).grow(-1))
    assert_equal(inv.item(0).id(), 0)


def test_remove_and_contains() raises:
    var inv = Inventory(3)
    inv.set_item(0, Stack(Stick(), 5))
    inv.set_item(2, Stack(Stick(), 5))
    assert_true(inv.contains_item(Stack(Stick(), 10)))
    assert_false(inv.contains_item(Stack(Stick(), 11)))
    inv.remove_item(Stack(Stick(), 7))
    assert_true(inv.item(0).empty())
    assert_equal(inv.item(2).count(), 3)
    with assert_raises():
        inv.remove_item(Stack(Stick(), 4))
    assert_true(inv.empty())


def test_first_and_clear() raises:
    var inv = Inventory(3)
    inv.set_item(1, Stack(Diamond(), 2))
    assert_equal(inv.first(Stack(Diamond(), 1)).value(), 1)
    assert_false(Bool(inv.first(Stack(Stick(), 1))))
    assert_equal(inv.first_empty().value(), 0)
    assert_equal(len(inv.clear()), 1)
    assert_true(inv.empty())
    with assert_raises(contains="out of range"):
        _ = inv.item(3)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
