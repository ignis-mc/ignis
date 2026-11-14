"""A `BlockSource` over a map, as Go tests build with a map-backed
`world.BlockSource`; positions not in the map are air."""

from std.collections import Dict
from std.memory import ArcPointer

from ignis.block.cube.pos import Pos
from ignis.world.block import Block
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.block_source import BlockSource


struct MapSource(BlockSource, Movable):
    """Blocks by position over a registry."""

    var br: ArcPointer[BasicBlockRegistry]
    var blocks: Dict[Pos, UInt32]

    def __init__(out self, br: ArcPointer[BasicBlockRegistry]):
        self.br = br
        self.blocks = Dict[Pos, UInt32]()

    def set[B: Block](mut self, pos: Pos, b: B):
        self.blocks[pos] = self.br[].block_runtime_id(b)

    def block(self, pos: Pos) -> UInt32:
        return self.blocks.get(pos).or_else(self.br[].air_runtime_id())

    def kind(self, rid: UInt32) -> UInt64:
        return self.br[].kind(rid)

    def state_hash(self, rid: UInt32) -> UInt64:
        return self.br[].state_hash(rid)


def derive_vectors(kind: String) raises -> List[List[Int]]:
    """Returns the lines of `derive_state.txt` for one kind as integers:
    facing, the four neighbour options and the result."""
    var out = List[List[Int]]()
    var text = open("test/data/behaviour/derive_state.txt", "r").read()
    for line in text.splitlines():
        var parts = line.split(" ")
        if len(parts) != 7 or String(parts[0]) != kind:
            continue
        var row = List[Int]()
        for i in range(1, 7):
            row.append(Int(String(parts[i])))
        out.append(row^)
    return out^
