from ignis.block.barrel import Barrel
from ignis.block.block import UseContext, User, calculate_face
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.cube.rotation import Rotation
from ignis.block.register import VanillaBlocks
from ignis.item.diamond import Diamond
from ignis.item.stack import Stack
from ignis.mgl64 import Vec3
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.world_runtime import new_vanilla_world


def test_calculate_face() raises:
    # Far away: towards the user, who looks south (yaw 0), so north.
    var far = User(Rotation(0, 0), Vec3(0.5, 0, 10.5), 1.62)
    assert_true(calculate_face(far, Pos(0, 0, 0)) == Face.NORTH)
    # Standing on top: the eyes are more than 2 above, so up.
    var above = User(Rotation(0, 90), Vec3(0.5, 1, 0.5), 1.62)
    assert_true(calculate_face(above, Pos(0, 0, 0)) == Face.UP)
    # Placing above the eyes: down.
    var below = User(Rotation(0, -90), Vec3(0.5, 0, 0.5), 1.62)
    assert_true(calculate_face(below, Pos(0, 2, 0)) == Face.DOWN)


def test_open_and_close_set_the_state() raises:
    var w = new_vanilla_world(items=True)
    var pos = Pos(2, -60, 2)
    w.set_block(pos, Barrel(facing=Face.UP, custom_name="Fish"))
    var inv = w.inventory(pos).value().copy()
    inv.set_item(0, Stack(Diamond(), 1))
    w.set_inventory(pos, inv^)
    var ctx = UseContext()
    assert_true(VanillaBlocks.activate(Barrel.BASE_HASH, pos, Face.UP, w, ctx))
    assert_true(ctx.open_container)
    VanillaBlocks.opened(Barrel.BASE_HASH, pos, w)
    var rid = w.block(pos)
    var br = w.block_registry()
    assert_true(Barrel.from_hash(br[].state_hash(rid)).open)
    VanillaBlocks.closed(Barrel.BASE_HASH, pos, w)
    assert_false(Barrel.from_hash(br[].state_hash(w.block(pos))).open)
    # The state change keeps the name and the contents.
    assert_equal(w.block_as[Barrel](pos).value().custom_name, "Fish")
    assert_equal(w.inventory(pos).value().item(0).count(), 1)


def test_breaking_drops_the_contents() raises:
    var w = new_vanilla_world(items=True)
    var pos = Pos(2, -60, 2)
    w.set_block(pos, Barrel())
    var inv = w.inventory(pos).value().copy()
    inv.set_item(26, Stack(Diamond(), 2))
    w.set_inventory(pos, inv^)
    VanillaBlocks.handle_break(Barrel.BASE_HASH, pos, w, False)
    var drops = w.take_item_drops()
    assert_equal(len(drops), 1)
    # Go drops barrel contents at the corner, not the centre.
    assert_equal(drops[0].pos, Vec3(2, -60, 2))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
