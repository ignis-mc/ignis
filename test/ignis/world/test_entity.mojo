from ignis.block.cube.rotation import Rotation
from ignis.entity.text import Text
from ignis.mgl64 import Vec3
from ignis.world.entity import EntityData, EntityHandle, EntitySpawnOpts
from minecraft.nbt.decode import decode
from minecraft.nbt.encode import encode
from minecraft.nbt.nbt import LITTLE_ENDIAN
from minecraft.protocol.uuid import UUID
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.world_runtime import TestEntities, Walker


def test_entity_data_defaults() raises:
    var d = EntityData()
    assert_true(d.always_show_name_tag)
    assert_equal(d.age_ms, 0)


def test_set_dispatch() raises:
    var t = TestEntities.wrap(Text())
    var w = TestEntities.wrap(Walker(3))
    assert_equal(TestEntities.identifier(t), "dragonfly:text")
    assert_equal(TestEntities.network_identifier(t), "minecraft:falling_block")
    assert_equal(TestEntities.network_identifier(w), "ignis:walker")
    assert_true(TestEntities.ticks(w))
    assert_equal(TestEntities.bbox(w, EntityData()).max(), Vec3(0.5, 1, 0.5))


def test_nbt_round_trip() raises:
    var opts = EntitySpawnOpts()
    opts.position = Vec3(1.5, 2, -3.25)
    opts.rotation = Rotation(90, -10)
    opts.velocity = Vec3(0, 0.5, 0)
    opts.name_tag = "Bob"
    var b = List[UInt8](length=16, fill=0)
    b[8] = 0x81
    b[15] = 7
    opts.id = UUID(Span(b))
    var e = EntityHandle[TestEntities](opts, TestEntities.wrap(Walker(5)))
    e.data.age_ms = 1000
    e.data.fire_duration_ms = 100
    var t = e.encode_nbt()
    # Through the on-disk encoding and back.
    var raw = encode(t, LITTLE_ENDIAN)
    var decoded = EntityHandle[TestEntities].decode_nbt(
        e.saved_id(), decode(Span(raw), LITTLE_ENDIAN)
    )
    var back = decoded.take()
    assert_true(back.id == e.id)
    assert_equal(back.data.pos, e.data.pos)
    assert_equal(back.data.vel, e.data.vel)
    assert_equal(back.data.rot, e.data.rot)
    assert_equal(back.data.name, "Bob")
    assert_equal(back.data.age_ms, 1000)
    assert_equal(back.data.fire_duration_ms, 100)
    assert_equal(back.state[Walker].steps, 5)
    assert_equal(back.identifier(), "ignis:walker")
    # Go: the saved ID is the last 8 bytes of the UUID, little endian.
    assert_equal(e.saved_id(), Int64(0x0700000000000081))


def test_unknown_identifier() raises:
    var e = EntityHandle[TestEntities](
        EntitySpawnOpts(), TestEntities.wrap(Text())
    )
    var t = e.encode_nbt()
    _ = t.put_string(t.root(), "identifier", "minecraft:pig")
    assert_false(EntityHandle[TestEntities].decode_nbt(1, t))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
