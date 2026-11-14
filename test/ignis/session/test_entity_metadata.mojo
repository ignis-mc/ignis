"""Tests for `ignis.session.entity_metadata`: the metadata of world
entities, marshalled, equal to Dragonfly's (`interop/entities/metadata.go`).
The firework's NBT has its keys sorted on both sides (Go's map order is
random)."""

from std.collections import Dict
from std.testing import TestSuite, assert_equal

from minecraft.nbt.decode import decode
from minecraft.nbt.encode import encode
from minecraft.nbt.nbt import NBT, NETWORK_LITTLE_ENDIAN
from minecraft.protocol.entity_metadata import (
    ENTITY_DATA_KEY_DISPLAY_FIREWORK,
    EntityMetadata,
    entity_metadata as write_entity_metadata,
)
from minecraft.protocol.writer import Writer
from nethernet.wire import hex_encode

from minecraft.nbt.tree import Tree

from ignis.block.dirt import Dirt
from ignis.block.hash import AnyBlock
from ignis.entity.item import ItemBehaviour
from ignis.item.stack import Stack
from ignis.block.sand import Sand
from ignis.entity.area_effect_cloud import AreaEffectCloud
from ignis.entity.arrow import Arrow
from ignis.entity.bottle_of_enchanting import BottleOfEnchanting
from ignis.entity.egg import Egg
from ignis.entity.ender_pearl import EnderPearl
from ignis.entity.experience_orb import ExperienceOrb
from ignis.entity.falling_block import FallingBlock
from ignis.entity.firework import Firework
from ignis.entity.lightning import Lightning
from ignis.entity.lingering_potion import LingeringPotion
from ignis.entity.register import VanillaEntities
from ignis.entity.snowball import Snowball
from ignis.entity.splash_potion import SplashPotion
from ignis.entity.text import new_text
from ignis.entity.tnt import TNT
from ignis.item.colour import Colour
from ignis.item.firework import Firework as FireworkItem
from ignis.item.firework_explosion import FireworkExplosion
from ignis.item.firework_shape import FireworkShape
from ignis.item.potion.potion import Potion
from ignis.mgl64 import Vec3
from ignis.session.entity_metadata import entity_metadata
from ignis.world.block_state import BlockState
from ignis.world.entity import EntityHandle, EntitySpawnOpts, EntityType

from support.item_vectors import sorted_tree

comptime _POS = Vec3(0.5, -60, 0.5)


def _vectors() raises -> Dict[String, String]:
    var out = Dict[String, String]()
    with open("test/data/entities/metadata.txt", "r") as f:
        for l in f.read().split("\n"):
            var parts = String(l).split("\t")
            if len(parts) == 2:
                out[String(parts[0])] = String(parts[1])
    return out^


def _hex(var m: EntityMetadata) raises -> String:
    var w = Writer(0)
    write_entity_metadata(w, m)
    return hex_encode(Span(w.take()))


def _split_firework(var m: EntityMetadata) raises -> Tuple[String, String]:
    # As the Go side writes it: the firework's NBT with sorted keys, and the
    # metadata without it.
    var nbt_hex = String()
    var rest = EntityMetadata()
    for ref e in m.entries:
        if e.key == ENTITY_DATA_KEY_DISPLAY_FIREWORK:
            var t = decode(Span(e.value[NBT].raw), NETWORK_LITTLE_ENDIAN)
            nbt_hex = hex_encode(
                Span(encode(sorted_tree(t), NETWORK_LITTLE_ENDIAN))
            )
        else:
            rest.entries.append(e.copy())
    return (_hex(rest^), nbt_hex)


def _check[
    E: EntityType
](v: Dict[String, String], name: String, var e: E) raises:
    var opts = EntitySpawnOpts()
    opts.position = _POS
    var h = EntityHandle[VanillaEntities](opts, VanillaEntities.wrap(e^))
    assert_equal(_hex(entity_metadata(h)), v[name], name)


def test_projectiles() raises:
    var v = _vectors()
    _check(v, "snowball", Snowball())
    _check(v, "egg", Egg())
    _check(v, "ender_pearl", EnderPearl())
    _check(v, "arrow", Arrow())
    var tipped = Arrow()
    tipped.proj.potion = Potion.STRENGTH
    _check(v, "tipped_arrow", tipped^)
    _check(v, "splash_water", SplashPotion())
    var healing = SplashPotion()
    healing.proj.potion = Potion.HEALING
    _check(v, "splash_healing", healing^)
    var swiftness = LingeringPotion()
    swiftness.proj.potion = Potion.SWIFTNESS
    _check(v, "lingering_swiftness", swiftness^)
    _check(v, "xp_bottle", BottleOfEnchanting())


def test_others() raises:
    var v = _vectors()
    _check(v, "xp_orb", ExperienceOrb(37))
    var explosions = List[FireworkExplosion]()
    explosions.append(
        FireworkExplosion(
            shape=FireworkShape.HUGE_SPHERE, colour=Colour.RED, twinkle=True
        )
    )
    explosions.append(
        FireworkExplosion(
            shape=FireworkShape.STAR,
            colour=Colour.BLUE,
            fade=Colour.WHITE,
            fades=True,
        )
    )
    var opts = EntitySpawnOpts()
    opts.position = _POS
    var fw = EntityHandle[VanillaEntities](
        opts,
        VanillaEntities.wrap(
            Firework(FireworkItem(duration=1000, explosions=explosions^), 1000)
        ),
    )
    var parts = _split_firework(entity_metadata(fw))
    assert_equal(parts[0], v["firework"], "firework")
    assert_equal(parts[1], v["firework_nbt"], "firework NBT")
    _check(v, "tnt", TNT(3000))
    _check(v, "lightning", Lightning())
    _check(v, "cloud", AreaEffectCloud(Potion.HARMING))
    _check(
        v,
        "falling_sand",
        FallingBlock(AnyBlock(Sand()), BlockState("minecraft:sand")),
    )
    _check(v, "item", ItemBehaviour(Stack(Dirt(), 1), Tree()))
    var t = new_text[VanillaEntities]("hello", _POS)
    assert_equal(_hex(entity_metadata(t)), v["text"], "text")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
