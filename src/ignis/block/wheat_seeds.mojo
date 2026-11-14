"""`WheatSeeds`, ported from Dragonfly `server/block/wheat_seeds.go`.

TODO(world-runtime): the `crop` helpers (NeighbourUpdateTick, HasLiquidDrops,
CalculateGrowthChance), GrowthStage, SameCrop, RandomTick, BoneMeal, UseOnBlock
and the drops.
"""

from ..item.item import Compostable
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    new_break_info,
)
from .hash import HASH_WHEAT_SEEDS
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable


struct WheatSeeds(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidRemovable,
    ModelledBlock,
):
    """A crop that can be harvested to obtain wheat."""

    comptime BASE_HASH: UInt64 = HASH_WHEAT_SEEDS
    """Go `hashWheatSeeds`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var growth: Int
    """The growth stage of the crop, 0 to 7 (Go `crop.Growth`)."""

    def __init__(out self, *, growth: Int = 0):
        """Creates the block; omitted fields take Go zero values."""
        self.growth = growth

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:wheat",
            Properties().with_int("growth", Int32(self.growth)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.growth)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return WheatSeeds(growth=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for growth in range(8):
            out.append(WheatSeeds(growth=growth))
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

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:wheat_seeds", 0)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.3

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def has_liquid_drops(self) -> Bool:
        """Returns True (Go `HasLiquidDrops`)."""
        return True
