"""`ReinforcedDeepslate`, ported from Dragonfly
`server/block/reinforced_deepslate.go`.

TODO(world-runtime): EncodeItem and the drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_REINFORCED_DEEPSLATE
from .model.solid import Solid as SolidModel


struct ReinforcedDeepslate(
    Block, Breakable, Equatable, ImplicitlyCopyable, ModelledBlock
):
    """A very strong block found in ancient cities."""

    comptime BASE_HASH: UInt64 = HASH_REINFORCED_DEEPSLATE
    """Go `hashReinforcedDeepslate`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `ReinforcedDeepslate{}`)."""
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
        return BlockState("minecraft:reinforced_deepslate")

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
        return ReinforcedDeepslate()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [ReinforcedDeepslate()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            55, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE
        ).with_blast_resistance(1200)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()
