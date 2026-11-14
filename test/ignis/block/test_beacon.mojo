from ignis.block.beacon import Beacon, recalculate_level
from ignis.block.cube.pos import Pos
from ignis.block.iron import Iron
from ignis.block.stone import Stone
from ignis.entity.effect import SECOND
from ignis.entity.living_request import REQUEST_EFFECT, LivingRequest
from ignis.entity.player_proxy import PlayerProxy
from ignis.mgl64 import Vec3
from ignis.world.world import World
from minecraft.nbt.tree import Tree
from minecraft.protocol.uuid import UUID
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from support.entity_vectors import spawn
from support.world_runtime import VanillaWorld, new_vanilla_world

comptime _BEACON = Pos(0, -59, 0)
"""A beacon on a 3x3 layer that replaces the flat world's top dirt."""


def _world(layers: Int) raises -> World[VanillaWorld]:
    var w = new_vanilla_world(random_tick_speed=-1)
    for cx in range(-1, 1):
        for cz in range(-1, 1):
            _ = w.block(Pos(cx << 4, 0, cz << 4))
    for l in range(1, layers + 1):
        for x in range(-l, l + 1):
            for z in range(-l, l + 1):
                w.set_block(Pos(x, _BEACON.y() - l, z), Iron())
    w.set_block(_BEACON, Beacon())
    spawn(w, Vec3(3.5, -58, 0.5), Vec3(), PlayerProxy())
    return w^


def _requests(mut w: World[VanillaWorld]) raises -> List[LivingRequest]:
    for id in w.entities():
        var s = w.entity_state(id)
        if s and s.value().isa[PlayerProxy]():
            var st = s.take()
            return st[PlayerProxy].requests.copy()
    raise Error("no proxy")


def _tick_to_broadcast(mut w: World[VanillaWorld]):
    for _ in range(81):
        w.advance_tick()


def test_nbt_keeps_effects() raises:
    var b = Beacon(level=3)
    b.primary = 1
    b.secondary = 10
    var t = Tree()
    b.encode_nbt(t, t.root())
    assert_equal(t.get_int(t.root(), "Primary"), 1)
    var back = Beacon().decode_nbt(t, t.root())
    assert_true(back == b)


def test_pyramid_levels() raises:
    var w = _world(2)
    assert_equal(recalculate_level(_BEACON, w), 2)
    # A gap in the lower layer leaves one level.
    w.set_block(Pos(2, _BEACON.y() - 2, 2), Stone())
    assert_equal(recalculate_level(_BEACON, w), 1)


def test_gives_effects_to_players_in_range() raises:
    var w = _world(1)
    var b = Beacon()
    b.primary = 1
    w.set_block(_BEACON, b)
    _tick_to_broadcast(w)
    assert_equal(w.block_as[Beacon](_BEACON).value().level, 1)
    var found = False
    for ref r in _requests(w):
        if r.kind != REQUEST_EFFECT:
            continue
        found = True
        assert_equal(len(r.effects), 1)
        # Go: level 1 lasts 9 + 2 s, ambient Speed I.
        assert_equal(r.effects[0].type_id(), 1)
        assert_equal(r.effects[0].level(), 1)
        assert_equal(r.effects[0].duration(), 11 * SECOND)
        assert_true(r.effects[0].ambient())
    assert_true(found)


def test_level_one_drops_strength() raises:
    var w = _world(1)
    var b = Beacon()
    b.primary = 5
    w.set_block(_BEACON, b)
    _tick_to_broadcast(w)
    for ref r in _requests(w):
        assert_false(r.kind == REQUEST_EFFECT)


def test_obstructed_beam_gives_nothing() raises:
    var w = _world(1)
    var b = Beacon()
    b.primary = 1
    w.set_block(_BEACON, b)
    w.set_block(_BEACON.add(Pos(0, 5, 0)), Stone())
    _tick_to_broadcast(w)
    for ref r in _requests(w):
        assert_false(r.kind == REQUEST_EFFECT)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
