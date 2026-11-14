"""Neighbour updates of blocks: falling blocks (`entity.falling_block`),
plants, torches, doors and the like breaking without support, sponges and
farmland. The worlds of `interop/behaviour/neighbours.go`, compared with
Dragonfly."""

from std.testing import TestSuite

from ignis.block.dragon_egg import DragonEgg
from ignis.block.cactus import Cactus
from ignis.block.carpet import Carpet
from ignis.block.concrete_powder import ConcretePowder
from ignis.block.cube.face import Face
from ignis.block.cube.pos import Pos
from ignis.block.double_tall_grass import DoubleTallGrass
from ignis.block.farmland import Farmland
from ignis.block.flower import Flower
from ignis.block.gravel import Gravel
from ignis.block.lantern import Lantern
from ignis.block.leaves import Leaves
from ignis.block.sand import Sand
from ignis.block.sponge import Sponge
from ignis.block.stone import Stone
from ignis.block.sugar_cane import SugarCane
from ignis.block.torch import Torch
from ignis.block.water import Water
from ignis.block.wood_door import WoodDoor
from ignis.item.colour import Colour

from support.behaviour_vectors import ScenarioRun
from support.world_runtime import new_vanilla_world

comptime _PATH = "test/data/behaviour/neighbours.txt"
comptime _LO = Pos(-4, -63, -4)
comptime _HI = Pos(16, -54, 12)


def _water() -> Water:
    return Water(still=True, depth=8)


def test_falling() raises:
    var w = new_vanilla_world(random_tick_speed=-1)
    w.set_block(Pos(0, -55, 0), Sand())
    w.set_block(Pos(2, -58, 0), Gravel())
    w.set_block(Pos(2, -57, 0), Gravel())
    w.set_block(Pos(2, -56, 0), Sand(red=True))
    w.set_block(Pos(4, -61, 0), Torch(facing=Face.DOWN))
    w.set_block(Pos(4, -57, 0), Sand())
    w.set_liquid(Pos(6, -61, 0), _water())
    w.set_block(Pos(6, -57, 0), ConcretePowder(colour=Colour.RED))
    w.set_block(Pos(8, -60, 0), DragonEgg())
    w.set_block(Pos(10, -61, 0), ConcretePowder())
    w.set_liquid(Pos(11, -61, 0), _water())
    var run = ScenarioRun(_PATH, "falling", _LO, _HI)
    run.check_until(w)


def test_pops() raises:
    var w = new_vanilla_world(random_tick_speed=-1)
    w.set_block(Pos(0, -61, 3), Torch(facing=Face.DOWN))
    w.set_block(Pos(2, -61, 3), Flower())
    w.set_block(Pos(4, -61, 3), DoubleTallGrass())
    w.set_block(Pos(4, -60, 3), DoubleTallGrass(upper_part=True))
    w.set_block(Pos(6, -61, 3), WoodDoor())
    w.set_block(Pos(6, -60, 3), WoodDoor(top=True))
    w.set_liquid(Pos(9, -62, 3), _water())
    w.set_block(Pos(8, -61, 3), SugarCane())
    w.set_block(Pos(8, -60, 3), SugarCane())
    w.set_block(Pos(10, -62, 3), Sand())
    w.set_block(Pos(10, -63, 3), Stone())
    w.set_block(Pos(10, -61, 3), Cactus())
    w.set_block(Pos(12, -61, 3), Lantern())
    w.set_block(Pos(14, -61, 3), Carpet())
    w.set_block(Pos(0, -62, 6), Farmland())
    w.set_block(Pos(2, -61, 6), Leaves())
    w.set_liquid(Pos(4, -61, 8), _water())
    var run = ScenarioRun(_PATH, "pops", _LO, _HI)
    run.check_until(w, 8)
    # Go `popsChanges`.
    var air = w.block_registry()[].air_runtime_id()
    w.set_block_runtime_id(Pos(0, -62, 3), air)
    w.set_block_runtime_id(Pos(2, -62, 3), air)
    w.set_block_runtime_id(Pos(4, -61, 3), air)
    w.set_block_runtime_id(Pos(6, -62, 3), air)
    w.remove_liquid(Pos(9, -62, 3))
    w.set_block(Pos(11, -61, 3), Stone())
    w.set_block_runtime_id(Pos(12, -62, 3), air)
    w.set_block_runtime_id(Pos(14, -62, 3), air)
    w.set_block(Pos(0, -61, 6), Stone())
    w.set_block(Pos(5, -61, 8), Sponge())
    run.check_until(w)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
