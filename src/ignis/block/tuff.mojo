"""`Tuff`, ported from Dragonfly `server/block/tuff.go`.

TODO(world-runtime): EncodeItem, SmeltInfo and the `oneOf` drops.
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
from .hash import HASH_TUFF


struct Tuff(Block, Breakable, Equatable, ImplicitlyCopyable):
    """An ornamental rock formed from volcanic ash."""

    comptime BASE_HASH: UInt64 = HASH_TUFF
    """Go `hashTuff`."""

    var chiseled: Bool
    """Whether the tuff is chiseled."""

    def __init__(out self, *, chiseled: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            chiseled: Whether the tuff is chiseled.
        """
        self.chiseled = chiseled

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
        if self.chiseled:
            return BlockState("minecraft:chiseled_tuff")
        return BlockState("minecraft:tuff")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(1) if self.chiseled else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Tuff(chiseled=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Tuff(), Tuff(chiseled=True)]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)
