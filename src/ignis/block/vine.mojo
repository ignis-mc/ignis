"""`Vines`, ported from Dragonfly `server/block/vine.go`.

Go's `replaceable` helper (ReplaceableBy) comes with `world.Tx`. Go's
`sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes with
liquids.

TODO(world-runtime): EntityInside, SideClosed, UseOnBlock,
NeighbourUpdateTick, RandomTick, CompostChance, FlammabilityInfo,
WithAttachment, SetAttachment, Attachment, Attachments, EncodeItem and the
drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .break_info import (
    AXE_EFFECTIVE,
    TOOL_TYPE_SHEARS,
    BreakInfo,
    Breakable,
    ToolFilter,
    new_break_info,
)
from .hash import HASH_VINES
from .model.empty import Empty as EmptyModel


struct Vines(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A climbable block that grows on walls and in the shade."""

    comptime BASE_HASH: UInt64 = HASH_VINES
    """Go `hashVines`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var north_direction: Bool
    """Whether the vines are attached towards north."""
    var east_direction: Bool
    """Whether the vines are attached towards east."""
    var south_direction: Bool
    """Whether the vines are attached towards south."""
    var west_direction: Bool
    """Whether the vines are attached towards west."""

    def __init__(
        out self,
        *,
        north_direction: Bool = False,
        east_direction: Bool = False,
        south_direction: Bool = False,
        west_direction: Bool = False,
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            north_direction: Whether the vines are attached towards north.
            east_direction: Whether the vines are attached towards east.
            south_direction: Whether the vines are attached towards south.
            west_direction: Whether the vines are attached towards west.
        """
        self.north_direction = north_direction
        self.east_direction = east_direction
        self.south_direction = south_direction
        self.west_direction = west_direction

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
        var bits = (
            Int32(self.south_direction)
            | Int32(self.west_direction) << 1
            | Int32(self.north_direction) << 2
            | Int32(self.east_direction) << 3
        )
        return BlockState(
            "minecraft:vine", Properties().with_int("vine_direction_bits", bits)
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            (UInt64(1) if self.north_direction else UInt64(0))
            | (UInt64(1) if self.east_direction else UInt64(0)) << 1
            | (UInt64(1) if self.south_direction else UInt64(0)) << 2
            | (UInt64(1) if self.west_direction else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Vines(
            north_direction=hash & 0x1 != 0,
            east_direction=(hash >> 1) & 0x1 != 0,
            south_direction=(hash >> 2) & 0x1 != 0,
            west_direction=(hash >> 3) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for north_direction in [False, True]:
            for east_direction in [False, True]:
                for south_direction in [False, True]:
                    for west_direction in [False, True]:
                        out.append(
                            Vines(
                                north_direction=north_direction,
                                east_direction=east_direction,
                                south_direction=south_direction,
                                west_direction=west_direction,
                            )
                        )
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.2, ToolFilter(TOOL_TYPE_SHEARS), AXE_EFFECTIVE)

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
