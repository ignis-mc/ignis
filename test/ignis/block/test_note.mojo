from ignis.block.block import UseContext
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.gold import Gold
from ignis.block.note import Note
from ignis.block.register import VanillaBlocks
from ignis.block.stone import Stone
from ignis.world.particle.block import Note as NoteParticle
from ignis.world.sound.block import Note as NoteSound
from ignis.world.sound.instrument import Instrument
from minecraft.nbt.tree import Tree
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.activate import particles, sounds, viewing
from support.world_runtime import new_vanilla_world


def test_note_item() raises:
    assert_equal(Note().encode_item().name, "minecraft:noteblock")
    assert_equal(Note.all_items()[0].pitch, 24)
    assert_equal(Note().fuel_info().duration, 15000)


def test_note_nbt_round_trip() raises:
    var tag = Tree()
    Note(pitch=7, powered=True).encode_nbt(tag, tag.root())
    assert_equal(tag.get_byte(tag.root(), "note"), 7)
    assert_equal(tag.get_byte(tag.root(), "powered"), 1)
    var back = Note().decode_nbt(tag, tag.root())
    assert_equal(back.pitch, 7)
    assert_true(back.powered)
    # Missing keys decode to Go's zero values.
    var empty = Tree()
    assert_equal(Note(pitch=3).decode_nbt(empty, empty.root()).pitch, 0)


def test_activate_raises_the_pitch() raises:
    var w = new_vanilla_world()
    var id = viewing(w)
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Note(pitch=24))
    var ctx = UseContext()
    assert_true(VanillaBlocks.activate(Note.BASE_HASH, pos, Face.UP, w, ctx))
    # 24 wraps to 0; the pitch is kept in the block entity.
    assert_equal(w.block_as[Note](pos).value().pitch, 0)
    assert_equal(sounds(w, id, NoteSound.SOUND_ID), 1)
    assert_equal(particles(w, id, NoteParticle.PARTICLE_ID), 1)
    _ = VanillaBlocks.activate(Note.BASE_HASH, pos, Face.UP, w, ctx)
    assert_equal(w.block_as[Note](pos).value().pitch, 1)


def test_needs_air_above() raises:
    var w = new_vanilla_world()
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Note(pitch=3))
    w.set_block(pos.side(Face.UP), Stone())
    var ctx = UseContext()
    assert_false(VanillaBlocks.activate(Note.BASE_HASH, pos, Face.UP, w, ctx))
    assert_equal(w.block_as[Note](pos).value().pitch, 3)


def test_instrument_from_the_block_below() raises:
    var w = new_vanilla_world()
    var pos = Pos(2, -61, 2)
    w.set_block(pos, Note())
    # Grass (no instrument) gives the piano.
    assert_true(Note().instrument_at(pos, w) == Instrument.PIANO)
    w.set_block(pos.side(Face.DOWN), Gold())
    assert_true(Note().instrument_at(pos, w) == Instrument.BELL)
    w.set_block(pos.side(Face.DOWN), Stone())
    assert_true(Note().instrument_at(pos, w) == Instrument.BASS_DRUM)
    # The particle uses the note block's own instrument (Go `bass`).
    assert_true(Note().instrument() == Instrument.BASS)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
