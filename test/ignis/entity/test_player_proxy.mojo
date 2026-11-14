"""Tests for `ignis.entity.player_proxy`: what the world's entities ask of
a player through its proxy, with the numbers of Dragonfly's code
(`hitEntity`, `potionSplash`, `dealDamage`, `applyEffects`,
`moveToTarget`)."""

from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_true,
)

from minecraft.protocol.uuid import UUID

from ignis.block.cube.pos import Pos
from ignis.entity.area_effect_cloud import AreaEffectCloud
from ignis.entity.arrow import Arrow
from ignis.entity.damage import DAMAGE_LIGHTNING, DAMAGE_PROJECTILE
from ignis.entity.effect import SECOND
from ignis.entity.experience_orb import ExperienceOrb
from ignis.entity.lightning import Lightning
from ignis.entity.living_request import (
    REQUEST_COLLECT_EXPERIENCE,
    REQUEST_EFFECT,
    REQUEST_LIGHTNING,
    REQUEST_PROJECTILE_HIT,
    LivingRequest,
)
from ignis.entity.player_proxy import PlayerProxy
from ignis.entity.splash_potion import SplashPotion
from ignis.item.potion.potion import Potion
from ignis.mgl64 import Vec3
from ignis.world.world import World

from support.entity_vectors import spawn
from support.world_runtime import VanillaWorld, new_vanilla_world

comptime _AT = Vec3(2.5, -60, 0.5)
"""The proxy's feet, on the flat world's grass."""


def _world() raises -> World[VanillaWorld]:
    var w = new_vanilla_world(random_tick_speed=-1)
    for cx in range(-1, 2):
        for cz in range(-1, 2):
            _ = w.block(Pos(cx << 4, 0, cz << 4))
    spawn(w, _AT, Vec3(), PlayerProxy())
    return w^


def _proxy(mut w: World[VanillaWorld]) raises -> UUID:
    for id in w.entities():
        var s = w.entity_state(id)
        if s and s.value().isa[PlayerProxy]():
            return id
    raise Error("no proxy")


def _requests(mut w: World[VanillaWorld]) raises -> List[LivingRequest]:
    var found = w.entity_state(_proxy(w))
    var s = found.take()
    return s[PlayerProxy].requests.copy()


def test_not_saved() raises:
    var s = VanillaWorld.Entities.wrap(PlayerProxy())
    assert_false(VanillaWorld.Entities.saved(s))
    assert_true(VanillaWorld.Entities.living(s))
    assert_true(VanillaWorld.Entities.damageable(s))
    assert_true(
        VanillaWorld.Entities.saved(VanillaWorld.Entities.wrap(Arrow()))
    )


def test_arrow_hit() raises:
    # Go `hitEntity`: ceil(2 * |vel|) with the velocity before the tick,
    # knocked back from the position minus that velocity.
    var w = _world()
    spawn(w, Vec3(0.5, -59, 0.5), Vec3(1.5, 0, 0), Arrow())
    for _ in range(3):
        w.advance_tick()
    var r = _requests(w)
    assert_equal(len(r), 1)
    assert_equal(r[0].kind, REQUEST_PROJECTILE_HIT)
    assert_equal(r[0].dmg, 3)
    assert_equal(r[0].src.kind, DAMAGE_PROJECTILE)
    assert_almost_equal(r[0].force, 0.45)
    assert_almost_equal(r[0].height, 0.3608)
    assert_true(r[0].pos.x() < _AT.x())
    assert_equal(len(r[0].effects), 0)


def test_splash_potion() raises:
    # Go `potionSplash` on a direct hit: factor 1, the full 45 seconds.
    var w = _world()
    var p = SplashPotion()
    p.proj.potion = Potion.POISON
    spawn(w, Vec3(2.5, -57, 0.5), Vec3(0, -0.5, 0), p^)
    for _ in range(4):
        w.advance_tick()
    var r = _requests(w)
    assert_equal(len(r), 1)
    assert_equal(r[0].kind, REQUEST_EFFECT)
    assert_equal(len(r[0].effects), 1)
    assert_equal(r[0].effects[0].type_id(), 19)
    assert_equal(r[0].effects[0].level(), 1)
    assert_equal(r[0].effects[0].duration(), 45 * SECOND)


def test_lightning() raises:
    # Go `dealDamage`: 5 damage and 8 seconds of fire to the living.
    var w = _world()
    spawn(w, _AT, Vec3(), Lightning())
    w.advance_tick()
    var r = _requests(w)
    assert_equal(len(r), 1)
    assert_equal(r[0].kind, REQUEST_LIGHTNING)
    assert_equal(r[0].dmg, 5)
    assert_equal(r[0].src.kind, DAMAGE_LIGHTNING)
    assert_equal(r[0].fire_ms, 8000)
    assert_true(r[0].at_least)


def test_cloud() raises:
    # Go `applyEffects` at 500 ms of age: a quarter of the duration. Go's
    # `EntitiesWithin` leaves out entities on the box's faces, so the cloud
    # is a little below the feet.
    var w = _world()
    spawn(
        w,
        _AT.sub(Vec3(0, 0.2, 0)),
        Vec3(),
        AreaEffectCloud(Potion.REGENERATION),
    )
    for _ in range(10):
        w.advance_tick()
    assert_equal(len(_requests(w)), 0)
    w.advance_tick()
    var r = _requests(w)
    assert_equal(len(r), 1)
    assert_equal(r[0].kind, REQUEST_EFFECT)
    assert_equal(r[0].effects[0].type_id(), 10)
    assert_equal(r[0].effects[0].duration(), 45 * SECOND // 4)
    # The reapplication delay keeps it from applying again 10 ticks later.
    for _ in range(10):
        w.advance_tick()
    assert_equal(len(_requests(w)), 1)


def test_orb_collected() raises:
    # Go `findTarget` then `moveToTarget`: the orb flies to the collector
    # and is gone once it touches it.
    var w = _world()
    spawn(w, Vec3(4.5, -59.5, 0.5), Vec3(), ExperienceOrb(7))
    var collected = False
    for _ in range(60):
        w.advance_tick()
        if len(_requests(w)) > 0:
            collected = True
            break
    assert_true(collected)
    var r = _requests(w)
    assert_equal(r[0].kind, REQUEST_COLLECT_EXPERIENCE)
    assert_equal(r[0].value, 7)
    for id in w.entities():
        var s = w.entity_state(id)
        assert_false(s.value().isa[ExperienceOrb]())


def test_orb_ignores_non_collector() raises:
    # A proxy that cannot collect (dead or spectating) is not followed.
    var w = _world()
    var id = _proxy(w)
    var found = w.entity_state(id)
    var s = found.take()
    s[PlayerProxy].collects = False
    w.set_entity_state(id, s^)
    spawn(w, Vec3(3.0, -59.5, 0.5), Vec3(), ExperienceOrb(7))
    for _ in range(40):
        w.advance_tick()
    assert_equal(len(_requests(w)), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
