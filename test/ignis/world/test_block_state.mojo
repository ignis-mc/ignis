from ignis.world.block_state import (
    BlockState,
    Properties,
    PropertyValue,
    decode_block_state,
    state_key,
)
from minecraft.nbt.nbt import TAG_COMPOUND
from minecraft.nbt.tree import Tree
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_not_equal,
    assert_raises,
    assert_true,
)


def test_properties_stay_sorted() raises:
    var p = (
        Properties().with_string("b", "x").with_int("a", 1).with_bool("c", True)
    )
    assert_equal(String(p), "a=i:1,b=s:x,c=b:1")
    p.set("a", PropertyValue(int32=2))
    assert_equal(String(p), "a=i:2,b=s:x,c=b:1")
    assert_equal(len(p), 3)
    assert_true(p.contains("b"))
    assert_false(p.contains("d"))
    assert_equal(p.get("a").value(), PropertyValue(int32=2))
    assert_false(p.get("d"))


def test_bool_is_byte() raises:
    assert_equal(PropertyValue(bool=True), PropertyValue(byte=1))
    assert_not_equal(PropertyValue(byte=1), PropertyValue(int32=1))
    assert_true(PropertyValue(byte=1).as_bool())
    assert_false(PropertyValue(int32=1).as_bool())


def test_state_key_is_unambiguous() raises:
    # Go's hashProperties gives both of these the key "xy".
    var a = Properties().with_string("a", "xy").with_string("b", "")
    var b = Properties().with_string("a", "x").with_string("b", "y")
    assert_not_equal(state_key("n", a), state_key("n", b))
    # Property names count.
    assert_not_equal(
        state_key("n", Properties().with_byte("a", 1)),
        state_key("n", Properties().with_byte("b", 1)),
    )
    assert_equal(state_key("n", Properties()), "n")


def test_block_state_equality_ignores_version() raises:
    var a = BlockState("minecraft:stone", Properties(), 5)
    assert_true(a == BlockState("minecraft:stone"))
    assert_false(a == BlockState("minecraft:dirt"))


def test_decode_block_state() raises:
    var tree = Tree(TAG_COMPOUND)
    var root = tree.root()
    _ = tree.put_string(root, "name", "minecraft:test")
    var states = tree.put_compound(root, "states")
    _ = tree.put_byte(states, "open_bit", 1)
    _ = tree.put_int(states, "age", 3)
    _ = tree.put_string(states, "facing", "north")
    _ = tree.put_int(root, "version", 18168865)
    var s = decode_block_state(tree)
    assert_equal(s.name, "minecraft:test")
    assert_equal(s.version, 18168865)
    assert_equal(String(s.properties), "age=i:3,facing=s:north,open_bit=b:1")


def test_decode_rejects_other_property_types() raises:
    var tree = Tree(TAG_COMPOUND)
    var root = tree.root()
    _ = tree.put_string(root, "name", "minecraft:test")
    var states = tree.put_compound(root, "states")
    _ = tree.put_long(states, "x", 1)
    with assert_raises(contains="property x"):
        _ = decode_block_state(tree)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
