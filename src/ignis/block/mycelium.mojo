"""`Mycelium`, ported from Dragonfly `server/block/mycelium.go`.

TODO(world-runtime): SoilFor, RandomTick, Shovel, EncodeItem and the drops.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    SHOVEL_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_MYCELIUM


struct Mycelium(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A spreading dirt-type block found in mushroom fields."""

    comptime BASE_HASH: UInt64 = HASH_MYCELIUM
    """Go `hashMycelium`."""

    def __init__(out self):
        """Creates the block (Go `Mycelium{}`)."""
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
        return BlockState("minecraft:mycelium")

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
        return Mycelium()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Mycelium()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.6, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)
