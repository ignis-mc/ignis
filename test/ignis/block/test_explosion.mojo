"""Tests for `ignis.block.explosion`: the explosions of
`interop/entities/explosions.go`, with a generator seeded with (1, 2),
compared with Dragonfly."""

from std.testing import TestSuite

from minecraft.nbt.tree import Tree

from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.explosion import ExplosionConfig, ExplosionSource, explode
from ignis.block.dirt import Dirt
from ignis.block.glass import Glass
from ignis.block.obsidian import Obsidian
from ignis.block.planks import Planks
from ignis.block.stone import Stone
from ignis.block.tnt import TNT as TNTBlock
from ignis.block.torch import Torch
from ignis.block.water import Water
from ignis.entity.item import ItemBehaviour
from ignis.entity.tnt import TNT
from ignis.internal.rand import Rand
from ignis.item.stack import Stack
from ignis.mgl64 import Vec3
from ignis.world.tx import SetOpts
from ignis.world.world import World

from support.entity_vectors import (
    assert_lines_equal,
    block_lines,
    load_lines,
    spawn,
    vec_bits,
)
from support.world_runtime import VanillaWorld, new_vanilla_world

comptime _PATH = "test/data/entities/explosions.txt"


def _world() raises -> World[VanillaWorld]:
    var w = new_vanilla_world(random_tick_speed=-1)
    for cx in range(-1, 2):
        for cz in range(-1, 2):
            _ = w.block(Pos(cx << 4, 0, cz << 4))
    return w^


def _check(
    mut w: World[VanillaWorld],
    name: String,
    src: ExplosionSource,
    var c: ExplosionConfig,
) raises:
    explode(w, src, c)
    var got = block_lines(
        w, name + "\tblock", Pos(-10, -64, -10), Pos(10, -50, 10)
    )
    var items = 0
    for d in w.take_item_drops():
        items += d.stack.count()
    var others = List[String]()
    for id in w.entities():
        var h = w.entity(id).value().copy()
        if h.identifier() == "minecraft:item":
            items += h.state[ItemBehaviour].item.count()
            continue
        others.append(
            String(t"{name}\tentity\t{h.identifier()}\t{vec_bits(h.data.pos)}")
        )
    sort(others)
    got.append(String(t"{name}\titems\t{items}"))
    got += others^
    assert_lines_equal(got, load_lines(_PATH, name), name)


def test_mixed() raises:
    var w = _world()
    for y in range(-61, -57):
        w.set_block(Pos(3, y, 0), Stone())
        w.set_block(Pos(-3, y, 1), Obsidian())
        w.set_block(Pos(0, y, 3), Planks())
        w.set_block(Pos(1, y, -3), Glass())
    w.set_block(Pos(0, -61, -1), Torch(facing=Face.DOWN))
    w.set_block(Pos(2, -61, 2), TNTBlock())
    spawn(w, Vec3(1, -61, 1), Vec3(), ItemBehaviour(Stack(Dirt(), 3), Tree()))
    spawn(w, Vec3(-2, -61, -2), Vec3(0, 0.1, 0), TNT(1000))
    _check(
        w,
        "mixed",
        ExplosionSource(Vec3(0.5, -60.5, 0.5), 4),
        ExplosionConfig(Rand(1, 2)),
    )


def test_fire() raises:
    var w = _world()
    var c = ExplosionConfig(Rand(1, 2))
    c.spawn_fire = True
    c.item_drop_chance = 1
    _check(w, "fire", ExplosionSource(Vec3(0.5, -61, 0.5), 3), c^)


def test_water() raises:
    var w = _world()
    var opts = SetOpts()
    opts.disable_block_updates = True
    for x in range(-2, 3):
        for z in range(-2, 3):
            w.set_block(Pos(x, -62, z), Water(still=True, depth=8), opts)
    _check(
        w,
        "water",
        ExplosionSource(Vec3(0.5, -61.5, 0.5), 4),
        ExplosionConfig(Rand(1, 2)),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
