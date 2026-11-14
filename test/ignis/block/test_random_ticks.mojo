"""Random ticks of blocks: grass and mycelium, crops and stems, sugar cane,
cacti, bamboo, kelp, cocoa, nether wart, redstone ore, leaves, farmland,
ice and copper. The one-chunk worlds of `interop/behaviour/randomticks.go`
(read from the vector file), ticked with a seeded world generator and
compared with Dragonfly."""

from std.testing import TestSuite

from ignis.block.cube.pos import Pos

from support.behaviour_vectors import (
    BehaviourVectors,
    ScenarioRun,
    new_feature_world,
)

comptime _PATH = "test/data/behaviour/random_ticks.txt"


def _run(name: String) raises:
    var v = BehaviourVectors(_PATH)
    var w = new_feature_world(v.placements(name), v.speed(name))
    # Go loads the chunk before the first tick.
    _ = w.block(Pos(0, 0, 0))
    var run = ScenarioRun(_PATH, name, Pos(0, -63, 0), Pos(15, -55, 15))
    run.check_until(w)


def test_grass() raises:
    _run("grass")


def test_crops() raises:
    _run("crops")


def test_plants() raises:
    _run("plants")


def test_decay() raises:
    _run("decay")


def test_copper() raises:
    _run("copper")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
