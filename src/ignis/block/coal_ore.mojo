"""`CoalOre`, ported from Dragonfly `server/block/coal_ore.go`.

TODO(world-runtime): the drops.
"""

from ..item.coal import Coal
from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_COAL_ORE
from .model.solid import Solid as SolidModel
from .ore_type import OreType, ore_types


struct CoalOre(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    Smeltable,
):
    """A common ore."""

    comptime BASE_HASH: UInt64 = HASH_COAL_ORE
    """Go `hashCoalOre`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var type: OreType
    """The rock the ore is embedded in."""

    def __init__(out self, *, type: OreType = OreType.STONE):
        """Creates the block; omitted fields take Go zero values."""
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(String(t"minecraft:{self.type.prefix()}coal_ore"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return CoalOre(type=OreType(Int(hash & 0x1)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for type in ore_types():
            out.append(CoalOre(type=type))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return (
            new_break_info(
                self.type.hardness(), PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
            )
            .with_xp_drop_range(0, 2)
            .with_blast_resistance(3)
        )

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def smelt_info(self) -> SmeltInfo:
        """Returns what smelting the block gives (Go `SmeltInfo`)."""
        return SmeltInfo(Stack(Coal(), 1), 0.1, ores=True)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.type.prefix()}coal_ore"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for o in ore_types():
            out.append(Self(type=o))
        return out^
