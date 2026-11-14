"""`DeepslateTiles`, ported from Dragonfly
`server/block/deepslate_tiles.go`.

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
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_DEEPSLATE_TILES
from .model.solid import Solid as SolidModel


struct DeepslateTiles(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
    Smeltable,
):
    """A tiled variant of deepslate."""

    comptime BASE_HASH: UInt64 = HASH_DEEPSLATE_TILES
    """Go `hashDeepslateTiles`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var cracked: Bool
    """Whether the block is cracked."""

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
            return BlockState("minecraft:cracked_deepslate_tiles")
        return BlockState("minecraft:deepslate_tiles")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.cracked else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return DeepslateTiles(cracked=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [DeepslateTiles(cracked=True), DeepslateTiles()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            3.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def smelt_info(self) -> SmeltInfo:
        """Returns what smelting the block gives (Go `SmeltInfo`)."""
        if self.cracked:
            return SmeltInfo()
        return SmeltInfo(Stack(DeepslateTiles(cracked=True), 1), 0.1)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.cracked:
            return EncodedItem("minecraft:cracked_deepslate_tiles", 0)
        return EncodedItem("minecraft:deepslate_tiles", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self(cracked=True), Self()]
