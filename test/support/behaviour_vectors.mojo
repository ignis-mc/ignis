"""Compares worlds ticked by Ignis with the regions Dragonfly recorded in
`test/data/behaviour/*.txt` (written by `interop/behaviour`)."""

from std.collections import Dict
from std.testing import assert_equal

from ignis.block.bedrock import Bedrock
from ignis.block.cube.pos import Pos
from ignis.block.dirt import Dirt
from ignis.block.grass import Grass
from ignis.world.world import World, WorldTypes


struct BehaviourVectors(Movable):
    """The lines of one vector file, grouped by scenario and tick."""

    var _lines: Dict[String, List[String]]
    var _ticks: Dict[String, List[Int]]

    def __init__(out self, path: String) raises:
        self._lines = Dict[String, List[String]]()
        self._ticks = Dict[String, List[Int]]()
        var text: String
        with open(path, "r") as f:
            text = f.read()
        for raw in text.split("\n"):
            var line = String(raw)
            if line.byte_length() == 0:
                continue
            var parts = line.split("\t")
            var name = String(parts[0])
            var tick = Int(String(parts[1]))
            var key = String(t"{name}@{tick}")
            if key not in self._lines:
                self._lines[key] = List[String]()
                if name not in self._ticks:
                    self._ticks[name] = List[Int]()
                self._ticks[name].append(tick)
            var rest = String("\t").join(parts[2:])
            self._lines[key].append(rest)

    def ticks(self, name: String) raises -> List[Int]:
        """Returns the checkpoint ticks of a scenario."""
        return self._ticks[name].copy()

    def lines(self, name: String, tick: Int) raises -> List[String]:
        """Returns the recorded lines of a scenario at a tick."""
        return self._lines[String(t"{name}@{tick}")].copy()


def dump_region[
    T: WorldTypes
](mut w: World[T], lo: Pos, hi: Pos, entities: Int) -> List[String]:
    """Renders a region as `interop/behaviour` does: `x,y,z layer rid` for
    every block that differs from the flat world (grass at y=-62, dirt,
    bedrock, air above; layer 1 only for a liquid behind a non-liquid),
    then the entity count."""
    var out = List[String]()
    var br = w.block_registry()
    var air = br[].air_runtime_id()
    var grass = br[].block_runtime_id(Grass())
    var dirt = br[].block_runtime_id(Dirt())
    var bedrock = br[].block_runtime_id(Bedrock())
    for y in range(lo.y(), hi.y() + 1):
        var base = air
        if y == -62:
            base = grass
        elif y == -63:
            base = dirt
        elif y == -64:
            base = bedrock
        for z in range(lo.z(), hi.z() + 1):
            for x in range(lo.x(), hi.x() + 1):
                var pos = Pos(x, y, z)
                var rid = w.block(pos)
                if rid != base:
                    out.append(String(t"{x},{y},{z}\t0\t{rid}"))
                if br[].liquid_block(rid):
                    continue
                if case .Some(l) = w.liquid(pos):
                    out.append(String(t"{x},{y},{z}\t1\t{l}"))
    out.append(String(t"entities\t{entities}"))
    return out^


def expected_lines(
    v: BehaviourVectors, name: String, tick: Int
) raises -> List[String]:
    """Returns the recorded lines without the state names."""
    var out = List[String]()
    for l in v.lines(name, tick):
        var parts = l.split("\t")
        if len(parts) >= 4:
            out.append(String(t"{parts[0]}\t{parts[1]}\t{parts[2]}"))
        else:
            out.append(l)
    return out^


def assert_region_equal(
    got: List[String], want: List[String], label: String
) raises:
    """Fails with the first differing line of two dumps."""
    var n = min(len(got), len(want))
    for i in range(n):
        if got[i] != want[i]:
            assert_equal(got[i], want[i], String(t"{label}: line {i}"))
    assert_equal(len(got), len(want), String(t"{label}: line count"))
