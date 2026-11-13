"""`InfestedStoneBricks`, ported from Dragonfly
`server/block/infested_stone_bricks.go`.

TODO(world-runtime): the `silkTouchOnlyDrop` drops and the silverfish spawn.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_INFESTED_STONE_BRICKS
from .stone_bricks_type import StoneBricksType, stone_bricks_types


struct InfestedStoneBricks(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A stone bricks block that hides a silverfish."""

    comptime BASE_HASH: UInt64 = HASH_INFESTED_STONE_BRICKS
    """Go `hashInfestedStoneBricks`."""

    var type: StoneBricksType
    """The type of stone bricks."""

    def __init__(out self, *, type: StoneBricksType = StoneBricksType.NORMAL):
        """Creates the block; omitted fields take Go zero values.

        Args:
            type: The type of stone bricks.
        """
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state.
        """
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState(String(t"minecraft:infested_{self.type}"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return InfestedStoneBricks(type=StoneBricksType(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for type in stone_bricks_types():
            out.append(InfestedStoneBricks(type=type))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            0.75, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(0.75)
