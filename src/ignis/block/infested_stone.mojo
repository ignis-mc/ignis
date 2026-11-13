"""`InfestedStone`, ported from Dragonfly `server/block/infested_stone.go`.

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
from .hash import HASH_INFESTED_STONE


struct InfestedStone(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A stone block that hides a silverfish."""

    comptime BASE_HASH: UInt64 = HASH_INFESTED_STONE
    """Go `hashInfestedStone`."""

    def __init__(out self):
        """Creates the block (Go `InfestedStone{}`)."""
        pass

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
        return BlockState("minecraft:infested_stone")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return InfestedStone()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [InfestedStone()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            0.75, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(0.75)
