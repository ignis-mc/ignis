"""Tests for `ignis.session.sound` against Dragonfly `session/world.go`."""

from std.memory import ArcPointer
from std.testing import TestSuite, assert_equal, assert_true

from minecraft.protocol.packet.block_event import BlockEvent
from minecraft.protocol.packet.id import (
    ID_BLOCK_EVENT,
    ID_LEVEL_EVENT,
    ID_LEVEL_SOUND_EVENT,
    ID_PLAY_SOUND,
)
from minecraft.protocol.packet.level_event import (
    LEVEL_EVENT_PARTICLES_DRAGON_EGG,
    LEVEL_EVENT_SOUND_CLICK,
    LEVEL_EVENT_WAX_ON,
    LevelEvent,
)
from minecraft.protocol.packet.level_sound_event import (
    SOUND_EVENT_DOOR_OPEN,
    SOUND_EVENT_FALL_BIG,
    SOUND_EVENT_NOTE,
    SOUND_EVENT_RECORD_CAT,
    LevelSoundEvent,
)
from minecraft.protocol.packet.packet import PacketData
from minecraft.protocol.packet.play_sound import PlaySound

from ignis.block.cube.pos import Pos
from ignis.block.hash import AnyBlock
from ignis.block.register import vanilla_block_registry
from ignis.block.wood_door import WoodDoor
from ignis.block.wood_type import WoodType
from ignis.item.register import vanilla_item_registry
from ignis.mgl64 import Vec3
from ignis.session.sound import play_sound, view_particle
from ignis.session.viewer import PacketQueue
from ignis.world.particle.block import DragonEggTeleport, Note as NoteParticle
from ignis.world.sound.block import (
    Click,
    DoorOpen,
    MusicDiscPlay,
    Note,
    SignWaxed,
)
from ignis.world.sound.custom import Custom
from ignis.world.sound.disc_type import DiscType
from ignis.world.sound.entity import Fall
from ignis.world.sound.instrument import Instrument


def _queue() raises -> PacketQueue:
    return PacketQueue(
        ArcPointer(vanilla_block_registry()),
        ArcPointer(vanilla_item_registry()),
    )


def _data(q: PacketQueue, i: Int) raises -> PacketData:
    return PacketData.parse(Span(q.packets[i]))


def test_sounds() raises:
    var q = _queue()
    var pos = Vec3(1.5, 2.5, 3.5)

    var door = WoodDoor(wood=WoodType.SPRUCE, open=True)
    play_sound(q, pos, DoorOpen(block=AnyBlock(door)), False)
    var d = _data(q, 0)
    assert_equal(d.id(), ID_LEVEL_SOUND_EVENT)
    var pk = d.decode[LevelSoundEvent]()
    assert_equal(pk.sound_type, SOUND_EVENT_DOOR_OPEN)
    assert_equal(pk.extra_data, Int32(q.blocks[].block_runtime_id(door)))
    assert_equal(pk.entity_type, ":")
    assert_equal(pk.position.x, Float32(1.5))
    assert_true(not pk.disable_relative_volume)

    # Note: instrument << 8 | pitch.
    play_sound(q, pos, Note(instrument=Instrument.BELL, pitch=12), True)
    pk = _data(q, 1).decode[LevelSoundEvent]()
    assert_equal(pk.sound_type, SOUND_EVENT_NOTE)
    assert_equal(pk.extra_data, Int32((6 << 8) | 12))
    assert_true(pk.disable_relative_volume)

    play_sound(q, pos, MusicDiscPlay(disc_type=DiscType.CAT), False)
    pk = _data(q, 2).decode[LevelSoundEvent]()
    assert_equal(pk.sound_type, SOUND_EVENT_RECORD_CAT)
    assert_equal(pk.extra_data, -1)

    play_sound(q, pos, Fall(distance=5), False)
    pk = _data(q, 3).decode[LevelSoundEvent]()
    assert_equal(pk.sound_type, SOUND_EVENT_FALL_BIG)
    assert_equal(pk.entity_type, "minecraft:player")

    play_sound(q, pos, Click(), False)
    d = _data(q, 4)
    assert_equal(d.id(), ID_LEVEL_EVENT)
    assert_equal(d.decode[LevelEvent]().event_type, LEVEL_EVENT_SOUND_CLICK)

    # Go also sends an empty LevelSoundEvent after this one (not copied).
    play_sound(q, pos, SignWaxed(), False)
    assert_equal(len(q.packets), 6)
    assert_equal(
        _data(q, 5).decode[LevelEvent]().event_type, LEVEL_EVENT_WAX_ON
    )

    play_sound(q, pos, Custom(name="mob.cat.meow", volume=0.5, pitch=2), False)
    d = _data(q, 6)
    assert_equal(d.id(), ID_PLAY_SOUND)
    var ps = d.decode[PlaySound]()
    assert_equal(ps.sound_name, "mob.cat.meow")
    assert_equal(ps.volume, Float32(0.5))
    assert_equal(ps.pitch, Float32(2))


def test_particles() raises:
    var q = _queue()
    view_particle(
        q, Vec3(4, 5, 6), NoteParticle(instrument=Instrument.BASS, pitch=7)
    )
    var d = _data(q, 0)
    assert_equal(d.id(), ID_BLOCK_EVENT)
    var be = d.decode[BlockEvent]()
    assert_equal(be.event_type, Int32(4))
    assert_equal(be.event_data, Int32(7))
    assert_equal(be.position.x, Int32(4))

    view_particle(q, Vec3(0, 0, 0), DragonEggTeleport(diff=Pos(-3, 2, 1)))
    var le = _data(q, 1).decode[LevelEvent]()
    assert_equal(le.event_type, LEVEL_EVENT_PARTICLES_DRAGON_EGG)
    assert_equal(le.event_data, Int32((3 << 16) | (2 << 8) | 1 | (1 << 24)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
