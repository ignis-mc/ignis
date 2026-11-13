"""`AncientDebris`, ported from Dragonfly `server/block/ancient_debris.go`.

TODO(world-runtime): EncodeItem, SmeltInfo and the drops.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from .break_info import (
    HARVEST_LEVEL_DIAMOND,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
    pickaxe_harvestable_from,
)
from .hash import HASH_ANCIENT_DEBRIS


struct AncientDebris(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A rare ore found within the nether."""

    comptime BASE_HASH: UInt64 = HASH_ANCIENT_DEBRIS
    """Go `hashAncientDebris`."""

    def __init__(out self):
        """Creates the block (Go `AncientDebris{}`)."""
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
        return BlockState("minecraft:ancient_debris")

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
        return AncientDebris()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [AncientDebris()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            30,
            pickaxe_harvestable_from(HARVEST_LEVEL_DIAMOND),
            PICKAXE_EFFECTIVE,
        ).with_blast_resistance(1200)
