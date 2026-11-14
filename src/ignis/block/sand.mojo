"""`Sand`, ported from Dragonfly `server/block/sand.go`.

TODO(world-runtime): SoilFor, NeighbourUpdateTick and the falling behaviour
of `gravityAffected`, SmeltInfo, EncodeItem and the drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    SHOVEL_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_SAND
from .model.solid import Solid as SolidModel


struct Sand(Block, Breakable, Equatable, ImplicitlyCopyable, ModelledBlock):
    """A block affected by gravity, found in deserts and beaches."""

    comptime BASE_HASH: UInt64 = HASH_SAND
    """Go `hashSand`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var red: Bool
    """Whether the sand is red sand."""

    def __init__(out self, *, red: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            red: Whether the sand is red sand.
        """
        self.red = red

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
        if self.red:
            return BlockState("minecraft:red_sand")
        return BlockState("minecraft:sand")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(1) if self.red else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Sand(red=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Sand(red=True), Sand()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.5, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()
