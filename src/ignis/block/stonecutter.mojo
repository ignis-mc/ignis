"""`Stonecutter`, ported from Dragonfly `server/block/stonecutter.go`.

TODO(world-runtime): Activate, UseOnBlock, Model, SideClosed, EncodeItem and
the drops.
"""

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_STONECUTTER
from .model.stonecutter import Stonecutter as StonecutterModel


struct Stonecutter(
    Block, Breakable, Equatable, ImplicitlyCopyable, ModelledBlock
):
    """A block used to cut stone-like materials into their slabs, stairs and walls.
    """

    comptime BASE_HASH: UInt64 = HASH_STONECUTTER
    """Go `hashStonecutter`."""
    comptime ModelType = StonecutterModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the stonecutter faces."""

    def __init__(out self, *, facing: Direction = Direction.NORTH):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The direction the stonecutter faces.
        """
        self.facing = facing

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
        return BlockState(
            "minecraft:stonecutter_block",
            Properties().with_string(
                "minecraft:cardinal_direction", String(self.facing)
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(Int(self.facing))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Stonecutter(facing=Direction(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for facing in directions():
            out.append(Stonecutter(facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(3.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def model(self) -> StonecutterModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return StonecutterModel()
