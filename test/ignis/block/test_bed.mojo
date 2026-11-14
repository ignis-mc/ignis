from ignis.block.bed import (
    MESSAGE_BED_OBSTRUCTED,
    MESSAGE_BED_TOO_FAR,
    MESSAGE_NO_SLEEP,
    MESSAGE_RESPAWN_POINT_SET,
    Bed,
)
from ignis.block.block import UseContext
from ignis.block.cube.direction import Direction
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.register import VanillaBlocks
from ignis.block.stone import Stone
from ignis.item.colour import Colour
from ignis.mgl64 import Vec3
from ignis.world.world import World
from minecraft.nbt.tree import Tree
from minecraft.protocol.uuid import UUID
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)
from support.world_runtime import VanillaWorld, new_vanilla_world

comptime FOOT = Pos(4, -61, 4)
"""The foot of a bed whose head is to the north."""


def _bed(mut w: World[VanillaWorld]):
    w.set_block(FOOT, Bed(colour=Colour.RED, facing=Direction.NORTH))
    w.set_block(
        FOOT.side(Face.NORTH),
        Bed(colour=Colour.RED, facing=Direction.NORTH, head=True),
    )


def _user(pos: Vec3) raises -> UseContext:
    var ctx = UseContext()
    var raw = List[UInt8](length=16, fill=7)
    ctx.user = UUID(Span(raw))
    ctx.user_pos = pos
    return ctx^


def test_nbt_round_trip() raises:
    var t = Tree()
    Bed(colour=Colour.CYAN).encode_nbt(t, t.root())
    assert_equal(t.get_byte(t.root(), "color"), 9)
    assert_true(Bed().decode_nbt(t, t.root()).colour == Colour.CYAN)


def test_invalid_colour_raises() raises:
    var t = Tree()
    _ = t.put_byte(t.root(), "color", 16)
    with assert_raises():
        _ = Bed().decode_nbt(t, t.root())


def test_encode_item() raises:
    var e = Bed(colour=Colour.RED).encode_item()
    assert_equal(e.name, "minecraft:bed")
    assert_equal(e.meta, 14)


def test_activate_sets_the_spawn_at_the_head() raises:
    var w = new_vanilla_world()
    _bed(w)
    var ctx = _user(Vec3(4.5, -61, 5.5))
    assert_true(VanillaBlocks.activate(Bed.BASE_HASH, FOOT, Face.UP, w, ctx))
    assert_true(w.player_spawn(ctx.user) == FOOT.side(Face.NORTH))
    # Daytime without thunder: Go refuses to sleep.
    assert_equal(len(ctx.messages), 2)
    assert_equal(ctx.messages[0], MESSAGE_RESPAWN_POINT_SET)
    assert_equal(ctx.messages[1], MESSAGE_NO_SLEEP)
    # The spawn is already there: only the sleep message.
    var again = _user(Vec3(4.5, -61, 5.5))
    _ = VanillaBlocks.activate(Bed.BASE_HASH, FOOT, Face.UP, w, again)
    assert_equal(len(again.messages), 1)
    assert_equal(again.messages[0], MESSAGE_NO_SLEEP)


def test_too_far_away() raises:
    var w = new_vanilla_world()
    _bed(w)
    var ctx = _user(Vec3(4.5, -61, 10.5))
    assert_true(VanillaBlocks.activate(Bed.BASE_HASH, FOOT, Face.UP, w, ctx))
    assert_equal(len(ctx.messages), 1)
    assert_equal(ctx.messages[0], MESSAGE_BED_TOO_FAR)
    assert_false(w.player_spawn(ctx.user) == FOOT.side(Face.NORTH))


def test_half_a_bed_does_nothing() raises:
    var w = new_vanilla_world()
    w.set_block(FOOT, Bed(facing=Direction.NORTH))
    var ctx = _user(Vec3(4.5, -61, 5.5))
    assert_false(VanillaBlocks.activate(Bed.BASE_HASH, FOOT, Face.UP, w, ctx))
    assert_equal(len(ctx.messages), 0)


def test_obstructed() raises:
    var w = new_vanilla_world()
    _bed(w)
    # Fill every spawn candidate around the bed with stone.
    for dx in range(-2, 3):
        for dz in range(-3, 3):
            for dy in range(0, 2):
                var p = FOOT.add(Pos(dx, dy, dz))
                if dy == 0 and dx == 0 and (dz == 0 or dz == -1):
                    continue
                w.set_block(p, Stone())
    w.set_block(FOOT.add(Pos(0, 1, 0)), Stone())
    w.set_block(FOOT.add(Pos(0, 1, -1)), Stone())
    var ctx = _user(Vec3(4.5, -61, 5.5))
    assert_false(VanillaBlocks.activate(Bed.BASE_HASH, FOOT, Face.UP, w, ctx))
    assert_equal(ctx.messages[0], MESSAGE_BED_OBSTRUCTED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
