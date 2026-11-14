"""`DoubleTallGrass`, ported from Dragonfly
`server/block/double_tall_grass.go`.

Go's `replaceable` helper (ReplaceableBy) comes with `world.Tx`.

TODO(world-runtime): NeighbourUpdateTick, HasLiquidDrops, UseOnBlock, BoneMeal,
FlammabilityInfo and the drops.
"""

from ..item.item import Compostable
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .double_tall_grass_type import DoubleTallGrassType, double_tall_grass_types
from .hash import HASH_DOUBLE_TALL_GRASS
from .model.empty import Empty as EmptyModel


struct DoubleTallGrass(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """A two block high variety of grass."""

    comptime BASE_HASH: UInt64 = HASH_DOUBLE_TALL_GRASS
    """Go `hashDoubleTallGrass`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var upper_part: Bool
    """Whether this is the upper part of the plant."""
    var type: DoubleTallGrassType
    """The type of double tall grass."""

    def __init__(
        out self,
        *,
        upper_part: Bool = False,
        type: DoubleTallGrassType = DoubleTallGrassType.NORMAL,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.upper_part = upper_part
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            String(t"minecraft:{self.type}"),
            Properties().with_bool("upper_block_bit", self.upper_part),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (UInt64(1) if self.upper_part else UInt64(0)) | UInt64(
            self.type.uint8()
        ) << 1

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return DoubleTallGrass(
            upper_part=hash & 0x1 != 0,
            type=DoubleTallGrassType(Int((hash >> 1) & 0x1)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for g in double_tall_grass_types():
            out.append(DoubleTallGrass(type=g))
            out.append(DoubleTallGrass(type=g, upper_part=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        if self.type == DoubleTallGrassType.FERN:
            return 0.65
        return 0.5

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.type}"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for g in double_tall_grass_types():
            out.append(Self(type=g))
        return out^
