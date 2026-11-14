from ignis.item.recipe.item import Item
from ignis.item.recipe.recipe import (
    RecipeKind,
    new_multi,
    new_shaped,
    new_shapeless,
)
from ignis.item.recipe.shape import new_shape
from ignis.item.stack import Stack
from ignis.item.stick import Stick
from ignis.item.coal import Coal
from minecraft.protocol.uuid import UUID
from std.testing import TestSuite, assert_equal, assert_true


def test_constructors() raises:
    var r = new_shapeless([Item(Stack(Coal(), 1))], Stack(Stick(), 4), "x")
    assert_true(r.kind == RecipeKind.SHAPELESS)
    assert_equal(len(r.input()), 1)
    assert_equal(r.output()[0].count(), 4)
    assert_equal(r.block(), "x")
    var s = new_shaped(
        [Item(Stack(Coal(), 1)), Item(Stack()), Item(Stack()), Item(Stack())],
        Stack(Stick(), 1),
        new_shape(2, 2),
        "crafting_table",
    )
    assert_equal(s.shape().width(), 2)
    assert_true(s.input()[1].empty())
    var m = new_multi(UUID())
    assert_equal(m.block(), "crafting_table")
    assert_equal(String(m.kind), "Multi")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
