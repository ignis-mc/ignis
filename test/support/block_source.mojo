"""A `BlockSource` over a fixed set of blocks, for model tests."""

from ignis.block.cube.pos import Pos
from ignis.world.block_registry import BasicBlockRegistry
from ignis.world.block_source import BlockSource
from std.collections import Dict


struct FixedSource(BlockSource, Movable):
    """Blocks at a few positions and air everywhere else."""

    var br: BasicBlockRegistry
    var blocks: Dict[Pos, UInt32]

    def __init__(out self, var br: BasicBlockRegistry):
        self.br = br^
        self.blocks = Dict[Pos, UInt32]()

    def block(self, pos: Pos) -> UInt32:
        if case .Some(rid) = self.blocks.get(pos):
            return rid
        return self.br.air()

    def kind(self, rid: UInt32) -> UInt64:
        return self.br.kind(rid)

    def state_hash(self, rid: UInt32) -> UInt64:
        return self.br.state_hash(rid)
