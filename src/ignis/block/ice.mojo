"""`Ice`, ported from Dragonfly `server/block/ice.go`.

TODO(world-runtime): Friction, RandomTick (melting), the break handler
turning it into water, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_ICE


struct Ice(Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser):
    """A solid block similar to packed ice."""

    comptime BASE_HASH: UInt64 = HASH_ICE
    """Go `hashIce`."""

    def __init__(out self):
        """Creates the block (Go `Ice{}`)."""
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
        return BlockState("minecraft:ice")

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
        return Ice()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Ice()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.5, ALWAYS_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 2
