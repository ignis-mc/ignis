"""`Lever`, ported from Dragonfly `server/block/lever.go`.

Go's `flowingWaterDisplacer` comes with liquids.

TODO(world-runtime): Activate, UseOnBlock, NeighbourUpdateTick,
HasLiquidDrops, SideClosed, RedstoneSource, RedstonePower,
RedstoneStrongPower, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction
from .cube.face import Face, faces
from .hash import HASH_LEVER
from .model.empty import Empty as EmptyModel


struct Lever(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A non-solid block that can provide switchable redstone power."""

    comptime BASE_HASH: UInt64 = HASH_LEVER
    """Go `hashLever`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var powered: Bool
    """Whether the lever is switched on."""
    var facing: Face
    """The face of the block the lever is attached to."""
    var direction: Direction
    """The direction the lever points when on a floor or ceiling."""

    def __init__(
        out self,
        *,
        powered: Bool = False,
        facing: Face = Face.DOWN,
        direction: Direction = Direction.NORTH,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            powered: Whether the lever is switched on.
            facing: The face of the block the lever is attached to.
            direction: The direction the lever points when on a floor or ceiling.
        """
        self.powered = powered
        self.facing = facing
        self.direction = direction

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
        var direction = String(self.facing)
        if self.facing == Face.DOWN or self.facing == Face.UP:
            var axis = "east_west"
            if self.direction == Direction.NORTH:
                axis = "north_south"
            direction += "_" + axis
        return BlockState(
            "minecraft:lever",
            Properties()
            .with_bool("open_bit", self.powered)
            .with_string("lever_direction", direction^),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            (UInt64(1) if self.powered else UInt64(0))
            | UInt64(Int(self.facing)) << 1
            | UInt64(Int(self.direction)) << 4
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Lever(
            powered=hash & 0x1 != 0,
            facing=Face(Int((hash >> 1) & 0x7)),
            direction=Direction(Int((hash >> 4) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for facing in faces():
            out.append(Lever(facing=facing, direction=Direction.NORTH))
            out.append(
                Lever(facing=facing, direction=Direction.NORTH, powered=True)
            )
            if facing == Face.DOWN or facing == Face.UP:
                out.append(Lever(facing=facing, direction=Direction.WEST))
                out.append(
                    Lever(facing=facing, direction=Direction.WEST, powered=True)
                )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.5, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return EmptyModel()
