from ignis.block.block import UseContext
from ignis.block.chest import Chest, chest_halves
from ignis.block.cube.direction import Direction
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.cube.rotation import Rotation
from ignis.block.register import VanillaBlocks
from ignis.block.stone import Stone
from ignis.item.diamond import Diamond
from ignis.item.stack import Stack
from ignis.mgl64 import Vec3
from ignis.world.block_set import decode_block_nbt, encode_block_nbt
from ignis.world.world import World
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_true,
)
from support.world_runtime import (
    RecordingViewer,
    VanillaWorld,
    new_vanilla_world,
)


def _place_all(mut w: World[VanillaWorld], pos: Pos, user: Rotation) -> Int:
    # What the server does with the placements of `use_on_block`.
    # Clicking the air at `pos` places into it (Go `firstReplaceable`).
    var list = Chest().use_on_block(pos, Face.UP, Vec3(0.5, 1, 0.5), user, w)
    var br = w.block_registry()
    for ref pl in list:
        var rid = br[].runtime_id_of(pl.block.kind, pl.block.state).value()
        w.set_block_runtime_id(pl.pos, rid)
        if case .Some(ref t) = pl.nbt:
            w.set_block_entity_nbt(pl.pos, t.copy())
    return len(list)


def test_placing_beside_a_chest_pairs_them() raises:
    var w = new_vanilla_world(items=True)
    # Yaw 0 looks south, so the chests face north; west and east of each
    # other they pair.
    assert_equal(_place_all(w, Pos(4, -60, 4), Rotation(0, 0)), 1)
    assert_equal(_place_all(w, Pos(5, -60, 4), Rotation(0, 0)), 2)
    var a = w.block_as[Chest](Pos(4, -60, 4)).value()
    var b = w.block_as[Chest](Pos(5, -60, 4)).value()
    assert_true(a.facing == Direction.NORTH)
    assert_true(a.paired and b.paired)
    assert_equal(a.pair_x, 5)
    assert_equal(b.pair_x, 4)
    # A third chest finds both neighbours taken and stays single.
    assert_equal(_place_all(w, Pos(6, -60, 4), Rotation(0, 0)), 1)
    assert_false(w.block_as[Chest](Pos(6, -60, 4)).value().paired)


def test_halves_left_first() raises:
    var w = new_vanilla_world(items=True)
    _ = _place_all(w, Pos(4, -60, 4), Rotation(0, 0))
    _ = _place_all(w, Pos(5, -60, 4), Rotation(0, 0))
    # Facing north, the chest's right is east: from (4) the east chest is
    # on the right, so it is the window's left half (Go `pair`).
    var h = chest_halves(Pos(4, -60, 4), w).value()
    assert_equal(h[0], Pos(5, -60, 4))
    assert_equal(h[1], Pos(4, -60, 4))
    var g = chest_halves(Pos(5, -60, 4), w).value()
    assert_equal(g[0], Pos(5, -60, 4))
    assert_equal(g[1], Pos(4, -60, 4))


def test_a_lost_pair_unpairs() raises:
    var w = new_vanilla_world(items=True)
    _ = _place_all(w, Pos(4, -60, 4), Rotation(0, 0))
    _ = _place_all(w, Pos(5, -60, 4), Rotation(0, 0))
    w.set_block(Pos(5, -60, 4), Stone())
    assert_false(chest_halves(Pos(4, -60, 4), w))
    assert_false(w.block_as[Chest](Pos(4, -60, 4)).value().paired)


def test_activate_needs_a_free_lid() raises:
    var w = new_vanilla_world(items=True)
    var pos = Pos(2, -60, 2)
    w.set_block(pos, Chest())
    var kind = Chest.BASE_HASH
    var ctx = UseContext()
    assert_true(VanillaBlocks.activate(kind, pos, Face.UP, w, ctx))
    assert_true(ctx.open_container)
    # A solid block on top keeps it shut, but still uses the click.
    w.set_block(pos.side(Face.UP), Stone())
    var shut = UseContext()
    assert_true(VanillaBlocks.activate(kind, pos, Face.UP, w, shut))
    assert_false(shut.open_container)


def test_lid_actions_for_both_halves() raises:
    var w = new_vanilla_world(items=True)
    var id = w.add_loader(0, RecordingViewer())
    w.load(id, 1000)
    _ = _place_all(w, Pos(4, -60, 4), Rotation(0, 0))
    _ = _place_all(w, Pos(5, -60, 4), Rotation(0, 0))
    VanillaBlocks.opened(Chest.BASE_HASH, Pos(4, -60, 4), w)
    assert_equal(w.viewer(id).count("block_action (4,-60,4) 0"), 1)
    assert_equal(w.viewer(id).count("block_action (5,-60,4) 0"), 1)
    VanillaBlocks.closed(Chest.BASE_HASH, Pos(4, -60, 4), w)
    assert_equal(w.viewer(id).count("block_action (5,-60,4) 1"), 1)


def test_breaking_drops_the_contents_and_unpairs() raises:
    var w = new_vanilla_world(items=True)
    _ = _place_all(w, Pos(4, -60, 4), Rotation(0, 0))
    _ = _place_all(w, Pos(5, -60, 4), Rotation(0, 0))
    var inv = w.inventory(Pos(4, -60, 4)).value().copy()
    inv.set_item(0, Stack(Diamond(), 3))
    inv.set_item(5, Stack(Diamond(), 4))
    w.set_inventory(Pos(4, -60, 4), inv^)
    VanillaBlocks.handle_break(Chest.BASE_HASH, Pos(4, -60, 4), w, True)
    var drops = w.take_item_drops()
    assert_equal(len(drops), 2)
    assert_equal(drops[0].stack.count() + drops[1].stack.count(), 7)
    assert_false(w.block_as[Chest](Pos(5, -60, 4)).value().paired)


def test_nbt_round_trip() raises:
    var c = Chest(facing=Direction.WEST, custom_name="Box").paired_with(
        Pos(-3, 0, 9)
    )
    var t = encode_block_nbt(c)
    var back = decode_block_nbt(Chest(facing=Direction.WEST), t)
    assert_true(back == c)
    assert_equal(t.get_int(t.root(), "pairz"), 9)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
