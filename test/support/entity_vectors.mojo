"""Replays the entity vectors of `interop/entities` (Dragonfly's projectile
flights and explosions) in Ignis worlds."""

from std.memory import bitcast
from std.testing import assert_equal

from ignis.block.bedrock import Bedrock
from ignis.block.cube.pos import Pos
from ignis.block.dirt import Dirt
from ignis.block.grass import Grass
from ignis.mgl64 import Vec3
from ignis.world.entity import EntityHandle, EntitySpawnOpts, EntityType
from ignis.world.world import World

from .world_runtime import VanillaWorld


def bits(v: Float64) -> String:
    """Formats a float's bits as 16 hex digits (Go `%016x` of `Float64bits`)."""
    var u = bitcast[DType.uint64](v)
    var digits = "0123456789abcdef"
    var out = String()
    for i in range(15, -1, -1):
        var d = Int((u >> UInt64(i * 4)) & 0xF)
        out += String(digits[byte=d])
    return out^


def vec_bits(v: Vec3) -> String:
    """Formats a vector as Go's `vec` does."""
    return String(t"{bits(v.x())},{bits(v.y())},{bits(v.z())}")


def load_lines(path: String, name: String) raises -> List[String]:
    """Returns the lines of a vector file for a scenario."""
    var out = List[String]()
    with open(path, "r") as f:
        for l in f.read().split("\n"):
            var line = String(l)
            if line.startswith(name + "\t"):
                out.append(line)
    return out^


def spawn[
    E: EntityType
](mut w: World[VanillaWorld], pos: Vec3, vel: Vec3, var e: E):
    """Adds an entity with a position and velocity."""
    var opts = EntitySpawnOpts()
    opts.position = pos
    opts.velocity = vel
    _ = w.add_entity(
        EntityHandle[VanillaWorld.Entities](
            opts, VanillaWorld.Entities.wrap(e^)
        )
    )


def record(mut w: World[VanillaWorld], name: String, tick: Int) -> List[String]:
    """Renders the entities as Go's `record` does."""
    var lines = List[String]()
    for id in w.entities():
        var h = w.entity(id).value().copy()
        var ident = h.identifier()
        if ident == "dragonfly:text" or ident == "minecraft:text":
            continue
        lines.append(
            String(
                t"{name}\t{tick}\tentity\t{ident}\t{vec_bits(h.data.pos)}\t{vec_bits(h.data.vel)}"
            )
        )
    sort(lines)
    if len(lines) == 0:
        lines.append(String(t"{name}\t{tick}\tnone"))
    return lines^


def block_lines(
    mut w: World[VanillaWorld], prefix: String, lo: Pos, hi: Pos
) -> List[String]:
    """Renders the blocks that differ from the flat world as Go's `blocks`
    does, each line starting with `prefix`."""
    var out = List[String]()
    var br = w.block_registry()
    var grass = br[].block_runtime_id(Grass())
    var dirt = br[].block_runtime_id(Dirt())
    var bedrock = br[].block_runtime_id(Bedrock())
    for y in range(lo.y(), hi.y() + 1):
        var base = br[].air_runtime_id()
        if y == -62:
            base = grass
        elif y == -63:
            base = dirt
        elif y == -64:
            base = bedrock
        for z in range(lo.z(), hi.z() + 1):
            for x in range(lo.x(), hi.x() + 1):
                var rid = w.block(Pos(x, y, z))
                if rid != base:
                    out.append(String(t"{prefix}\t{x},{y},{z}\t{rid}"))
    return out^


def assert_lines_equal(
    got: List[String], want: List[String], label: String
) raises:
    """Fails with the first differing line."""
    for i in range(min(len(got), len(want))):
        if got[i] != want[i]:
            assert_equal(got[i], want[i], String(t"{label}: line {i}"))
    assert_equal(len(got), len(want), String(t"{label}: line count"))
