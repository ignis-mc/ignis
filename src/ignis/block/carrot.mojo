"""`Carrot`, ported from Dragonfly `server/block/carrot.go`.

TODO(world-runtime): the `crop` helpers (NeighbourUpdateTick, HasLiquidDrops,
CalculateGrowthChance), GrowthStage, SameCrop, RandomTick, BoneMeal, UseOnBlock
and the drops.
"""

from ..item.item import (
    DEFAULT_CONSUME_DURATION,
    Compostable,
    Consumable,
    ConsumeInfo,
)
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
from .hash import HASH_CARROT
from .model.empty import Empty as EmptyModel


struct Carrot(
    Block,
    Breakable,
    Compostable,
    Consumable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """A crop that can be consumed raw."""

    comptime BASE_HASH: UInt64 = HASH_CARROT
    """Go `hashCarrot`."""
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
            "minecraft:carrots",
            Properties().with_int("growth", Int32(self.growth)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.growth)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Carrot(growth=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for growth in range(8):
            out.append(Carrot(growth=growth))
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
        return 0.65

    def always_consumable(self) -> Bool:
        """Reports whether it may be eaten with a full food bar (Go
        `AlwaysConsumable`)."""
        return False

    def consume_duration(self) -> Int:
        """Returns how long eating takes (Go `ConsumeDuration`)."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what eating the carrot does (Go `Consume`): 3 food, 3.6
        saturation."""
        return ConsumeInfo(3, 3.6)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:carrot", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
