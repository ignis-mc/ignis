"""`LapisOre`, ported from Dragonfly `server/block/lapis_ore.go`.

TODO(world-runtime): the drops.
"""

from ..item.lapis_lazuli import LapisLazuli
from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    HARVEST_LEVEL_STONE,
    PICKAXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
    pickaxe_harvestable_from,
)
from .hash import HASH_LAPIS_ORE
from .model.solid import Solid as SolidModel
from .ore_type import OreType, ore_types


struct LapisOre(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    Smeltable,
):
    """An ore block from which lapis lazuli is obtained."""

    comptime BASE_HASH: UInt64 = HASH_LAPIS_ORE
    """Go `hashLapisOre`."""
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
        return BlockState(String(t"minecraft:{self.type.prefix()}lapis_ore"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return LapisOre(type=OreType(Int(hash & 0x1)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for type in ore_types():
            out.append(LapisOre(type=type))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return (
            new_break_info(
                self.type.hardness(),
                pickaxe_harvestable_from(HARVEST_LEVEL_STONE),
                PICKAXE_EFFECTIVE,
            )
            .with_xp_drop_range(2, 5)
            .with_blast_resistance(3)
        )

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def smelt_info(self) -> SmeltInfo:
        """Returns what smelting the block gives (Go `SmeltInfo`)."""
        return SmeltInfo(Stack(LapisLazuli(), 1), 0.2, ores=True)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(
            String(t"minecraft:{self.type.prefix()}lapis_ore"), 0
        )

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for o in ore_types():
            out.append(Self(type=o))
        return out^
