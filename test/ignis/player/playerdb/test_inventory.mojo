from ignis.block.dirt import Dirt
from ignis.block.register import vanilla_block_registry
from ignis.item.diamond import Diamond
from ignis.item.register import vanilla_item_registry
from ignis.item.shears import Shears
from ignis.item.stack import Stack
from ignis.item.stick import Stick
from ignis.player.playerdb.inventory import (
    decode_item,
    encode_item,
    load_inventories,
    put_inventories,
)
from ignis.player.playerdb.json import Data
from ignis.session.inventory import Inventories
from minecraft.nbt.decode import decode
from minecraft.nbt.nbt import LITTLE_ENDIAN
from std.testing import TestSuite, assert_equal, assert_true


def test_item_round_trip() raises:
    var br = vanilla_block_registry("resources/block_states.nbt")
    var reg = vanilla_item_registry()
    var s = Stack(Shears(), 1).damage(17).with_custom_name("Snip")
    var b = encode_item(br, reg, s)
    # Go's disk layout: Name, Damage (meta), Count and the stack's tag.
    var t = decode(Span(b), LITTLE_ENDIAN)
    assert_equal(
        t.as_string(t.get(t.root(), "Name").value()), "minecraft:shears"
    )
    assert_equal(t.as_byte(t.get(t.root(), "Count").value()), 1)
    var tag = t.get(t.root(), "tag").value()
    assert_equal(t.as_short(t.get(tag, "Damage").value()), 17)
    var back = decode_item(reg, b)
    assert_true(back == s)
    assert_equal(back.custom_name(), "Snip")


def test_block_item_has_block_state() raises:
    var br = vanilla_block_registry("resources/block_states.nbt")
    var reg = vanilla_item_registry()
    var b = encode_item(br, reg, Stack(Dirt(), 12))
    var t = decode(Span(b), LITTLE_ENDIAN)
    var blk = t.get(t.root(), "Block").value()
    assert_equal(t.as_string(t.get(blk, "name").value()), "minecraft:dirt")
    var back = decode_item(reg, b)
    assert_equal(back.count(), 12)
    assert_true(Bool(back.item_as[Dirt]()))


def test_inventories_through_json() raises:
    var br = vanilla_block_registry("resources/block_states.nbt")
    var reg = vanilla_item_registry()
    var invs = Inventories()
    invs.inv.set_item(0, Stack(Stick(), 3))
    invs.inv.set_item(35, Stack(Dirt(), 64))
    invs.off_hand.set_item(0, Stack(Diamond(), 2))
    invs.ender_chest.set_item(5, Stack(Stick(), 1))
    invs.held_slot = 4
    var d = Data()
    put_inventories(d, br, reg, invs)
    assert_equal(len(d.items), 2)
    var json = d.to_json()
    assert_true('"Boots":null' in json)
    var back = Data.from_json(json.as_bytes())
    var loaded = Inventories()
    load_inventories(back, reg, loaded)
    assert_equal(loaded.inv.item(0).count(), 3)
    assert_equal(loaded.inv.item(35).count(), 64)
    assert_equal(loaded.off_hand_item().count(), 2)
    assert_equal(loaded.ender_chest.item(5).count(), 1)
    assert_equal(loaded.held_slot, 4)
    assert_true(loaded.inv.item(1).empty())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
