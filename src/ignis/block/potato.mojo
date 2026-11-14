"""`Potato`, ported from Dragonfly `server/block/potato.go`.

TODO(world-runtime): the `crop` helpers (NeighbourUpdateTick, HasLiquidDrops,
CalculateGrowthChance), GrowthStage, SameCrop, RandomTick, BoneMeal, UseOnBlock
and the drops.
"""

from ..item.baked_potato import BakedPotato
from ..item.item import (
    Compostable,
    Consumable,
    ConsumeInfo,
    DEFAULT_CONSUME_DURATION,
)
from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
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
from .hash import HASH_POTATO
from .model.empty import Empty as EmptyModel


struct Potato(
    Block,
    Breakable,
    Compostable,
    Consumable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    Smeltable,
):
    """A crop that can be consumed raw or cooked."""

    comptime BASE_HASH: UInt64 = HASH_POTATO
    """Go `hashPotato`."""
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
            "minecraft:potatoes",
            Properties().with_int("growth", Int32(self.growth)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.growth)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Potato(growth=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for growth in range(8):
            out.append(Potato(growth=growth))
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
        return EncodedItem("minecraft:potato", 0)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        return SmeltInfo(Stack(BakedPotato(), 1), 0.35, food=True)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.65

    def always_consumable(self) -> Bool:
        """Reports whether it may be eaten with a full food bar: no."""
        return False

    def consume_duration(self) -> Int:
        """Returns how long eating takes (Go `ConsumeDuration`)."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what eating does (Go `Consume`): 1 food, 0.6 saturation."""
        return ConsumeInfo(1, 0.6)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
