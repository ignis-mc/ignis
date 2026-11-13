from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.hash import AnyBlock
from ignis.block.stone import Stone
from ignis.internal.color import RGBA
from ignis.world.particle import Particle
from ignis.world.particle.block import (
    BlockBreak,
    DragonEggTeleport,
    Dust,
    Note,
    PunchBlock,
)
from ignis.world.particle.entity import HugeExplosion, Splash
from ignis.world.sound.instrument import Instrument
from std.testing import TestSuite, assert_equal, assert_true


def _id[P: Particle](p: P) -> Int:
    return P.PARTICLE_ID


def test_particles() raises:
    var ids = [
        _id(BlockBreak(block=AnyBlock(Stone()))),
        _id(PunchBlock(block=AnyBlock(Stone()), face=Face.UP)),
        _id(Dust(colour=RGBA(255, 0, 0, 255))),
        _id(Note(instrument=Instrument.BELL, pitch=12)),
        _id(DragonEggTeleport(diff=Pos(1, 2, 3))),
        _id(HugeExplosion()),
        _id(Splash(colour=RGBA())),
    ]
    for i in range(len(ids)):
        for j in range(i + 1, len(ids)):
            assert_true(ids[i] != ids[j])
    assert_equal(String(RGBA(1, 2, 3, 4)), "{1 2 3 4}")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
