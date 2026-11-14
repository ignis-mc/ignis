"""`PolishedBlackstoneBrick`, ported from Dragonfly
`server/block/polished_blackstone_brick.go`.

TODO(world-runtime): the `oneOf` drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .hash import HASH_POLISHED_BLACKSTONE_BRICK
from .model.solid import Solid as SolidModel


struct PolishedBlackstoneBrick(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
    Smeltable,
):
    """A brick variant of polished blackstone."""

    comptime BASE_HASH: UInt64 = HASH_POLISHED_BLACKSTONE_BRICK
    """Go `hashPolishedBlackstoneBrick`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var cracked: Bool
    """Whether the bricks are cracked."""

    def __init__(out self, *, cracked: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.cracked = cracked

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.cracked:
            return BlockState("minecraft:cracked_polished_blackstone_bricks")
        return BlockState("minecraft:polished_blackstone_bricks")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.cracked else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return PolishedBlackstoneBrick(cracked=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [
            PolishedBlackstoneBrick(cracked=True),
            PolishedBlackstoneBrick(),
        ]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.cracked:
            return EncodedItem(
                "minecraft:cracked_polished_blackstone_bricks", 0
            )
        return EncodedItem("minecraft:polished_blackstone_bricks", 0)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        if self.cracked:
            return SmeltInfo()
        return SmeltInfo(Stack(PolishedBlackstoneBrick(cracked=True), 1), 0.1)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [
            PolishedBlackstoneBrick(cracked=True),
            PolishedBlackstoneBrick(),
        ]
