"""`Diamond`, ported from Dragonfly `server/block/diamond.go`.

TODO(world-runtime): EncodeItem, SmeltInfo and the drops, PowersBeacon.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from .break_info import (
    HARVEST_LEVEL_IRON,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
    pickaxe_harvestable_from,
)
from .hash import HASH_DIAMOND


struct Diamond(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A block which can only be gained by crafting it."""

    comptime BASE_HASH: UInt64 = HASH_DIAMOND
    """Go `hashDiamond`."""

    def __init__(out self):
        """Creates the block (Go `Diamond{}`)."""
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
        return BlockState("minecraft:diamond_block")

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
        return Diamond()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Diamond()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            5, pickaxe_harvestable_from(HARVEST_LEVEL_IRON), PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)
