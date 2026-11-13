"""`Blackstone`, ported from Dragonfly `server/block/blackstone.go`.

TODO(world-runtime): EncodeItem and the drops (gilded blackstone drops gold
nuggets).
"""

from ..world.block import Block
from ..world.block_state import BlockState
from .blackstone_type import BlackstoneType, blackstone_types
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_BLACKSTONE


struct Blackstone(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A naturally generating block in the nether, similar to cobblestone."""

    comptime BASE_HASH: UInt64 = HASH_BLACKSTONE
    """Go `hashBlackstone`."""

    var type: BlackstoneType
    """The type of blackstone."""

    def __init__(out self, *, type: BlackstoneType = BlackstoneType.NORMAL):
        """Creates the block; omitted fields take Go zero values.

        Args:
            type: The type of blackstone.
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
        return BlockState(String(t"minecraft:{self.type}"))

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
        return Blackstone(type=BlackstoneType(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for type in blackstone_types():
            out.append(Blackstone(type=type))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        var hardness = 1.5
        if self.type == BlackstoneType.POLISHED:
            hardness = 2
        return new_break_info(
            hardness, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)
