"""`Vines`, ported from Dragonfly `server/block/vine.go`.

Go's `replaceable` helper is `Replaceable`. Go's
`sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes with
liquids.

TODO(world-runtime): EntityInside, SideClosed, UseOnBlock, NeighbourUpdateTick,
RandomTick, FlammabilityInfo, WithAttachment, SetAttachment, Attachment,
Attachments and the drops.
"""

from ..item.item import Compostable
from ..item.tool import TYPE_SHEARS
from .block import Replaceable
from .hash import AnyBlock
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    AXE_EFFECTIVE,
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
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    Replaceable,
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
        """Creates the block; omitted fields take Go zero values."""
        self.north_direction = north_direction
        self.east_direction = east_direction
        self.south_direction = south_direction
        self.west_direction = west_direction

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
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
        """Returns the state hash (Go `Hash`)."""
        return (
            (UInt64(1) if self.north_direction else UInt64(0))
            | (UInt64(1) if self.east_direction else UInt64(0)) << 1
            | (UInt64(1) if self.south_direction else UInt64(0)) << 2
            | (UInt64(1) if self.west_direction else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Vines(
            north_direction=hash & 0x1 != 0,
            east_direction=(hash >> 1) & 0x1 != 0,
            south_direction=(hash >> 2) & 0x1 != 0,
            west_direction=(hash >> 3) & 0x1 != 0,
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
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
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.2, ToolFilter(TYPE_SHEARS), AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def replaceable_by(self, b: AnyBlock) -> Bool:
        """Any block replaces it (Go's embedded `replaceable`)."""
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:vine", 0)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.5

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
