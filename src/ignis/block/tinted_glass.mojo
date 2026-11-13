"""`TintedGlass`, ported from Dragonfly `server/block/tinted_glass.go`.

TODO(world-runtime): PreventsSuffocation, EncodeItem and the drops.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_TINTED_GLASS


struct TintedGlass(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A decorative, fully transparent solid block that blocks light."""

    comptime BASE_HASH: UInt64 = HASH_TINTED_GLASS
    """Go `hashTintedGlass`."""

    def __init__(out self):
        """Creates the block (Go `TintedGlass{}`)."""
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
        return BlockState("minecraft:tinted_glass")

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
        return TintedGlass()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [TintedGlass()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            0.3, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE
        ).with_blast_resistance(0.3)
