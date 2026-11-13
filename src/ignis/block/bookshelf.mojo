"""`Bookshelf`, ported from Dragonfly `server/block/bookshelf.go`.

TODO(world-runtime): FlammabilityInfo, FuelInfo, EncodeItem and the drops.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_BOOKSHELF


struct Bookshelf(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A decorative block that primarily serves to enhance enchanting with an enchanting table.
    """

    comptime BASE_HASH: UInt64 = HASH_BOOKSHELF
    """Go `hashBookshelf`."""

    def __init__(out self):
        """Creates the block (Go `Bookshelf{}`)."""
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
        return BlockState("minecraft:bookshelf")

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
        return Bookshelf()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Bookshelf()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(1.5, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)
