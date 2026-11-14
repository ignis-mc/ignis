"""Tests for `Jukebox` (Go `jukebox.go`)."""

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from ignis.block.block import UseContext
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.jukebox import Jukebox
from ignis.block.register import VanillaBlocks
from ignis.item.inventory.inventory import Inventory
from ignis.item.music_disc import MusicDisc
from ignis.item.stack import Stack
from ignis.item.stick import Stick
from ignis.world.sound.block import MusicDiscEnd, MusicDiscPlay
from ignis.world.sound.disc_type import DiscType
from minecraft.nbt.tree import Tree
from support.activate import sounds, viewing
from support.world_runtime import new_vanilla_world


def test_insert_and_eject() raises:
    var w = new_vanilla_world()
    var id = viewing(w)
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Jukebox())
    var ctx = UseContext()
    ctx.held = Stack(MusicDisc(disc_type=DiscType.CAT), 1).with_custom_name(
        "Mine"
    )
    assert_true(VanillaBlocks.activate(Jukebox.BASE_HASH, pos, Face.UP, w, ctx))
    assert_equal(ctx.count_sub, 1)
    assert_equal(ctx.popup, "Now playing: C418 - cat")
    var j = w.block_as[Jukebox](pos).value().copy()
    assert_true(j.disc().value() == DiscType.CAT)
    assert_equal(j.item.custom_name(), "Mine")
    assert_equal(sounds(w, id, MusicDiscEnd.SOUND_ID), 1)
    assert_equal(sounds(w, id, MusicDiscPlay.SOUND_ID), 1)
    var nbt = w.block_entity_nbt(pos).value().copy()
    var rec = nbt.get(nbt.root(), "RecordItem").value()
    assert_equal(nbt.get_string(rec, "Name"), "minecraft:music_disc_cat")
    assert_equal(nbt.get_byte(rec, "Count"), 1)

    # Using it again ejects the disc above the jukebox.
    var empty = UseContext()
    assert_true(
        VanillaBlocks.activate(Jukebox.BASE_HASH, pos, Face.UP, w, empty)
    )
    assert_false(w.block_as[Jukebox](pos).value().disc())
    var drops = w.take_item_drops()
    assert_equal(len(drops), 1)
    assert_true(
        drops[0].stack.item_as[MusicDisc]().value().disc_type == DiscType.CAT
    )
    assert_equal(drops[0].stack.custom_name(), "Mine")
    assert_equal(empty.count_sub, 0)
    assert_equal(sounds(w, id, MusicDiscEnd.SOUND_ID), 2)


def test_other_items_are_not_inserted() raises:
    var w = new_vanilla_world()
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Jukebox())
    var ctx = UseContext()
    ctx.held = Stack(Stick(), 5)
    # Go returns true but inserts nothing.
    assert_true(VanillaBlocks.activate(Jukebox.BASE_HASH, pos, Face.UP, w, ctx))
    assert_equal(ctx.count_sub, 0)
    assert_false(w.block_as[Jukebox](pos).value().disc())


def test_nbt_round_trip() raises:
    var t = Tree()
    Jukebox(item=Stack(MusicDisc(disc_type=DiscType.PIGSTEP), 1)).encode_nbt(
        t, t.root()
    )
    assert_equal(t.get_string(t.root(), "id"), "Jukebox")
    var back = Jukebox().decode_nbt(t, t.root())
    assert_true(back.disc().value() == DiscType.PIGSTEP)
    var none = Tree()
    Jukebox().encode_nbt(none, none.root())
    assert_false(none.get(none.root(), "RecordItem"))


def test_hopper_inserts_a_disc() raises:
    var w = new_vanilla_world()
    var id = viewing(w)
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Jukebox())
    var hopper = Inventory(5)
    hopper.set_item(1, Stack(Stick(), 3))
    hopper.set_item(2, Stack(MusicDisc(disc_type=DiscType.WARD), 1))
    var j = w.block_as[Jukebox](pos).value().copy()
    assert_true(j.insert_item(hopper, Face.DOWN, pos, w))
    assert_true(hopper.item(2).empty())
    assert_equal(hopper.item(1).count(), 3)
    j = w.block_as[Jukebox](pos).value().copy()
    assert_true(j.disc().value() == DiscType.WARD)
    assert_equal(sounds(w, id, MusicDiscPlay.SOUND_ID), 1)
    # Full: nothing more goes in, and hoppers never take the disc out.
    hopper.set_item(0, Stack(MusicDisc(disc_type=DiscType.CAT), 1))
    assert_false(j.insert_item(hopper, Face.DOWN, pos, w))
    assert_false(j.extract_item(hopper, pos, w))
    # Breaking drops it.
    j.on_break(pos, w, True)
    assert_equal(len(w.take_item_drops()), 1)
    assert_equal(sounds(w, id, MusicDiscEnd.SOUND_ID), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
