"""`ShortGrass`, ported from Dragonfly `server/block/short_grass.go`.

Go's `replaceable` helper (ReplaceableBy) comes with `world.Tx`.

TODO(world-runtime): NeighbourUpdateTick, HasLiquidDrops, UseOnBlock, BoneMeal,
FlammabilityInfo and the drops.
"""

from ..item.item import Compostable
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    new_break_info,
)
from .hash import HASH_SHORT_GRASS
from .model.empty import Empty as EmptyModel


struct ShortGrass(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """Vegetation blocks generated on grass."""

    comptime BASE_HASH: UInt64 = HASH_SHORT_GRASS
    """Go `hashShortGrass`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var double: Bool
    """Unused by Dragonfly: it is not part of the state."""

    def __init__(out self, *, double: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.double = double

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash() and self.double == other.double

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:short_grass")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return ShortGrass()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [ShortGrass()]

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

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:short_grass", 0)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.65

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
