"""NBT round trips of the entity types (Go's `EncodeNBT` and `DecodeNBT`
keys): what is saved with a chunk comes back."""

from std.testing import TestSuite, assert_equal, assert_true

from minecraft.nbt.tree import Tree

from ignis.block.cube.pos import Pos
from ignis.entity.area_effect_cloud import AreaEffectCloud
from ignis.entity.arrow import Arrow
from ignis.entity.experience_orb import ExperienceOrb
from ignis.entity.firework import Firework
from ignis.entity.register import VanillaEntities
from ignis.entity.splash_potion import SplashPotion
from ignis.entity.tnt import TNT
from ignis.item.arrow import Arrow as ArrowItem
from ignis.item.colour import Colour
from ignis.item.firework import Firework as FireworkItem
from ignis.item.firework_explosion import FireworkExplosion
from ignis.item.potion.potion import Potion
from ignis.item.stack import Stack
from ignis.mgl64 import Vec3
from ignis.world.entity import EntityHandle, EntitySpawnOpts, EntityType


def _round_trip[E: EntityType](var e: E) raises -> VanillaEntities.State:
    var opts = EntitySpawnOpts()
    opts.position = Vec3(1.5, -60, 2.5)
    var h = EntityHandle[VanillaEntities](opts, VanillaEntities.wrap(e^))
    var t = h.encode_nbt()
    var back = EntityHandle[VanillaEntities].decode_nbt(h.saved_id(), t)
    assert_true(Bool(back), "decodes")
    var state = back.value().state.copy()
    return state^


def test_arrow() raises:
    var a = Arrow()
    a.proj.damage = 4.5
    a.proj.potion = Potion.STRENGTH
    a.proj.knock_back_force_addend = 0.5
    a.proj.pickup_item = Stack(ArrowItem(tip=Potion.STRENGTH), 1)
    a.proj.collided = True
    a.proj.collision_pos = Pos(3, -61, 4)
    var h = _round_trip(a^)
    var b = h[Arrow].copy()
    assert_equal(b.proj.damage, 4.5)
    assert_true(b.proj.potion == Potion.STRENGTH)
    assert_equal(b.proj.knock_back_force_addend, 0.5)
    assert_true(not b.proj.pickup_item.empty())
    assert_true(not b.proj.disable_pickup)
    # Go loses this (it reads an int array as a list); Ignis keeps it.
    assert_true(b.proj.collided)
    assert_true(b.proj.collision_pos == Pos(3, -61, 4))


def test_potions_orbs_tnt() raises:
    var s = SplashPotion()
    s.proj.potion = Potion.HARMING
    var hs = _round_trip(s^)
    assert_true(hs[SplashPotion].proj.potion == Potion.HARMING)
    var ho = _round_trip(ExperienceOrb(37))
    assert_equal(ho[ExperienceOrb].experience, 37)
    var ht = _round_trip(TNT(1500))
    assert_equal(ht[TNT].passive.fuse_ms, 1500)


def test_cloud() raises:
    var c = AreaEffectCloud(Potion.SWIFTNESS)
    c.radius = 2.5
    var h = _round_trip(c^)
    var b = h[AreaEffectCloud].copy()
    assert_true(b.potion == Potion.SWIFTNESS)
    assert_equal(b.radius, 2.5)
    assert_equal(b.radius_tick_growth, Float64(Float32(-0.005)))
    assert_equal(b.reapplication_delay_ms, 2000)
    assert_equal(b.duration_ms, 30000)


def test_firework() raises:
    var explosions = List[FireworkExplosion]()
    explosions.append(FireworkExplosion(colour=Colour.RED, twinkle=True))
    var f = Firework(FireworkItem(duration=1500, explosions=explosions^), 1700)
    var h = _round_trip(f^)
    var b = h[Firework].copy()
    assert_equal(len(b.firework.explosions), 1)
    assert_true(b.firework.explosions[0].twinkle)
    assert_equal(b.firework.duration, 1500)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
