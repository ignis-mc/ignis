"""`NetherQuartzOre`, ported from Dragonfly `server/block/quartz_ore.go`.

TODO(world-runtime): EncodeItem, SmeltInfo and the drops.
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
from .hash import HASH_NETHER_QUARTZ_ORE


struct NetherQuartzOre(Block, Breakable, Equatable, ImplicitlyCopyable):
    """An ore found in the nether."""

    comptime BASE_HASH: UInt64 = HASH_NETHER_QUARTZ_ORE
    """Go `hashNetherQuartzOre`."""

    def __init__(out self):
        """Creates the block (Go `NetherQuartzOre{}`)."""
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
        return BlockState("minecraft:quartz_ore")

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
        return NetherQuartzOre()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [NetherQuartzOre()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            3, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_xp_drop_range(0, 3)
