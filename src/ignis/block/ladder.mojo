"""`Ladder`, ported from Dragonfly `server/block/ladder.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): NeighbourUpdateTick, UseOnBlock, EntityInside,
SideClosed, Model, FuelInfo, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .block import UNKNOWN_DIRECTION
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_LADDER
from .model.ladder import Ladder as LadderModel


struct Ladder(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A wooden block used for climbing walls either vertically or horizontally.
    """

    comptime BASE_HASH: UInt64 = HASH_LADDER
    """Go `hashLadder`."""
    comptime ModelType = LadderModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the ladder faces; `UNKNOWN_DIRECTION` encodes as 0."""

    def __init__(out self, *, facing: Direction = Direction.NORTH):
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The direction the ladder faces; `UNKNOWN_DIRECTION` encodes as 0.
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
        var facing = Int32(0)
        if self.facing != UNKNOWN_DIRECTION:
            facing = Int32(Int(self.facing) + 2)
        return BlockState(
            "minecraft:ladder",
            Properties().with_int("facing_direction", facing),
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
        return Ladder(facing=Direction(Int(hash & 0x7)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for f in directions():
            out.append(Ladder(facing=f))
        out.append(Ladder(facing=UNKNOWN_DIRECTION))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.4, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> LadderModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return LadderModel(facing=self.facing)
