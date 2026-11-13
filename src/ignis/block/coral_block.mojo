"""`CoralBlock`, ported from Dragonfly `server/block/coral_block.go`.

TODO(world-runtime): NeighbourUpdateTick, ScheduledTick, EncodeItem and the
drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .coral_type import CoralType, coral_types
from .hash import HASH_CORAL_BLOCK
from .model.solid import Solid as SolidModel


struct CoralBlock(
    Block, Breakable, Equatable, ImplicitlyCopyable, ModelledBlock
):
    """A solid block that comes in 5 variants."""

    comptime BASE_HASH: UInt64 = HASH_CORAL_BLOCK
    """Go `hashCoralBlock`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var type: CoralType
    """The type of coral."""
    var dead: Bool
    """Whether the coral is dead."""

    def __init__(
        out self, *, type: CoralType = CoralType.TUBE, dead: Bool = False
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            type: The type of coral.
            dead: Whether the coral is dead.
        """
        self.type = type
        self.dead = dead

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
        var dead = "dead_" if self.dead else ""
        return BlockState(String(t"minecraft:{dead}{self.type}_coral_block"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.type.uint8())
            | (UInt64(1) if self.dead else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return CoralBlock(
            type=CoralType(Int(hash & 0x7)), dead=(hash >> 3) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for dead in [True, False]:
            for t in coral_types():
                out.append(CoralBlock(type=t, dead=dead))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()
