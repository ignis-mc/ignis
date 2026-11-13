"""`Note`, ported from Dragonfly `server/block/note.go`.

TODO(world-runtime): playNote, instrument, DecodeNBT, EncodeNBT, Punch,
Activate, RedstoneUpdate, FuelInfo, EncodeItem and the drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_NOTE
from .model.solid import Solid as SolidModel


struct Note(Block, Breakable, Equatable, ImplicitlyCopyable, ModelledBlock):
    """A musical block that emits sounds when powered or punched."""

    comptime BASE_HASH: UInt64 = HASH_NOTE
    """Go `hashNote`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var pitch: Int
    """The current pitch the note block is set to, 0 to 24."""
    var powered: Bool
    """Whether the note block was powered during its last redstone update."""

    def __init__(out self, *, pitch: Int = 0, powered: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            pitch: The current pitch the note block is set to, 0 to 24.
            powered: Whether the note block was powered during its last redstone update.
        """
        self.pitch = pitch
        self.powered = powered

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state and hold the same data.
        """
        return (
            self.hash() == other.hash()
            and self.pitch == other.pitch
            and self.powered == other.powered
        )

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
        return BlockState("minecraft:noteblock")

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
        return Note()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Note()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.8, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return SolidModel()
