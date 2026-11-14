from ignis.item.nbt import read_nbt, write_nbt
from ignis.item.shears import Shears
from ignis.item.stack import Enchantment, Stack
from ignis.item.stick import Stick
from minecraft.nbt.nbt import TAG_STRING
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_true
from support.item_vectors import canonical, load_item_vectors


def _c(t: Tree) raises -> String:
    return canonical(t, t.root())


def test_write_nbt_matches_dragonfly() raises:
    var v = load_item_vectors()
    assert_equal(_c(write_nbt(Stack(Stick(), 3))), v["stack.stick.nbt"])
    assert_equal(_c(write_nbt(Stack(Shears(), 1))), v["stack.shears.nbt"])
    assert_equal(
        _c(
            write_nbt(
                Stack(Shears(), 1)
                .damage(237)
                .with_custom_name("S")
                .as_unbreakable()
            )
        ),
        v["stack.shears_all.nbt"],
    )
    assert_equal(
        _c(write_nbt(Stack(Stick(), 1).with_lore(["a", "b"]))),
        v["stack.stick_lore.nbt"],
    )


def test_enchantments_round_trip() raises:
    var s = Stack(Shears(), 1).with_forced_enchantments(
        [Enchantment(17, 3), Enchantment(9, 1)]
    )
    var t = write_nbt(s)
    assert_equal(
        _c(t),
        "{x44616d616765=i0,x656e6368=[{x6964=s9,x6c766c=s1},{x6964=s17,x6c766c=s3}]}",
    )
    var back = read_nbt(t, Stack(Shears(), 1))
    assert_true(back == s)


def test_read_nbt_ignores_wrong_types() raises:
    var t = Tree()
    _ = t.put_short(t.root(), "Damage", 5)  # network damage is an int32
    var d = t.put_compound(t.root(), "display")
    _ = t.put_int(d, "Name", 3)
    _ = t.put_list(d, "Lore", TAG_STRING)
    var s = read_nbt(t, Stack(Shears(), 1))
    assert_equal(s.durability(), 238)
    assert_equal(s.custom_name(), "")
    assert_equal(len(s.lore()), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
