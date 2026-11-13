"""`Cobweb`, ported from Dragonfly `server/block/cobweb.go`.

TODO(world-runtime): Cobweb, EntityInside, EncodeItem and the drops (string
with shears).
"""

from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    SHEARS_EFFECTIVE,
    SWORD_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_COBWEB


struct Cobweb(Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser):
    """A block that slows down entities moving through it."""

    comptime BASE_HASH: UInt64 = HASH_COBWEB
    """Go `hashCobweb`."""

    def __init__(out self):
        """Creates the block (Go `Cobweb{}`)."""
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
        return BlockState("minecraft:web")

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
        return Cobweb()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Cobweb()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            4, ALWAYS_HARVESTABLE, SWORD_EFFECTIVE | SHEARS_EFFECTIVE
        )

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
