"""Tests for `ignis.world.chunk.light`: the world of
`interop/behaviour/light.go`, lit when its chunks load, compared with
Dragonfly."""

from std.testing import TestSuite, assert_equal

from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.glowstone import Glowstone
from ignis.block.leaves import Leaves
from ignis.block.planks import Planks
from ignis.block.stone import Stone
from ignis.block.torch import Torch
from ignis.block.water import Water
from ignis.world.world import World

from support.behaviour_vectors import (
    FeatureWorld,
    Placement,
    assert_region_equal,
    box,
    new_feature_world,
    vanilla_registry,
)


def light_features() raises -> List[Placement]:
    """Go `lightFeatures`."""
    var br = vanilla_registry()
    var p = List[Placement]()
    p += box(br, Pos(2, -58, 2), Pos(8, -58, 8), Stone())
    p += box(br, Pos(2, -61, 2), Pos(2, -59, 2), Stone())
    p += box(br, Pos(8, -61, 8), Pos(8, -59, 8), Stone())
    p.append(Placement(Pos(5, -61, 5), br.block_runtime_id(Glowstone())))
    p += box(br, Pos(10, -62, 10), Pos(12, -62, 12), Water(still=True, depth=8))
    p += box(br, Pos(14, -61, 1), Pos(14, -59, 1), Leaves())
    p += box(br, Pos(16, -61, 0), Pos(16, -55, 15), Stone())
    p.append(
        Placement(Pos(20, -61, 4), br.block_runtime_id(Torch(facing=Face.DOWN)))
    )
    p.append(Placement(Pos(-1, -61, 8), br.block_runtime_id(Glowstone())))
    p += box(br, Pos(-3, -57, -3), Pos(3, -57, 3), Planks())
    return p^


def test_light_matches_dragonfly() raises:
    var w = new_feature_world(light_features())
    for cx in range(-2, 3):
        for cz in range(-2, 3):
            _ = w.block(Pos(cx << 4, 0, cz << 4))
    var got = List[String]()
    for y in range(-63, -51):
        for z in range(-8, 25):
            for x in range(-8, 32):
                var pos = Pos(x, y, z)
                var sky = w.sky_light(pos)
                var bl = w.block_light(pos)
                var want_sky = UInt8(15) if y > -62 else UInt8(0)
                if sky != want_sky or bl != 0:
                    got.append(String(t"{x},{y},{z}\t{sky}\t{bl}"))
    var want = List[String]()
    with open("test/data/behaviour/light.txt", "r") as f:
        for l in f.read().split("\n"):
            if l.byte_length() > 0:
                want.append(String(l))
    assert_region_equal(got, want, "light")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
