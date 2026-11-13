"""`Glowstone`, ported from Dragonfly `server/block/glowstone.go`.

TODO(world-runtime): Instrument, CanRedstoneWireStepDown,
RedstoneNonConductive, EncodeItem and the drops.
"""

from ..world.block import Block, LightEmitter
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_GLOWSTONE


struct Glowstone(Block, Breakable, Equatable, ImplicitlyCopyable, LightEmitter):
    """A naturally generating block found in the nether that emits light."""

    comptime BASE_HASH: UInt64 = HASH_GLOWSTONE
    """Go `hashGlowstone`."""

    def __init__(out self):
        """Creates the block (Go `Glowstone{}`)."""
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
        return BlockState("minecraft:glowstone")

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
        return Glowstone()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Glowstone()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.3, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        return 15
