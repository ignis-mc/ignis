"""`StainedTerracotta`, ported from Dragonfly
`server/block/stained_terracotta.go`.

TODO(world-runtime): the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..item.colour import Colour, colours
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
from .glazed_terracotta import GlazedTerracotta
from .hash import AnyBlock, HASH_DEAD_BUSH, HASH_STAINED_TERRACOTTA
from .model.solid import Solid as SolidModel
from .dirt import Soil


struct StainedTerracotta(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
    Smeltable,
    Soil,
):
    """A block formed from clay, with a hardness and blast resistance comparable to stone.
    """

    comptime BASE_HASH: UInt64 = HASH_STAINED_TERRACOTTA
    """Go `hashStainedTerracotta`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var colour: Colour
    """The colour of the terracotta."""

    def __init__(out self, *, colour: Colour = Colour.WHITE):
        """Creates the block; omitted fields take Go zero values."""
        self.colour = colour

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(String(t"minecraft:{self.colour}_terracotta"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.colour.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return StainedTerracotta(colour=Colour(Int(hash & 0xF)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for colour in colours():
            out.append(StainedTerracotta(colour=colour))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(1.25, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.colour}_terracotta"), 0)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        return SmeltInfo(Stack(GlazedTerracotta(colour=self.colour), 1), 0.1)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in colours():
            out.append(StainedTerracotta(colour=v))
        return out^

    def soil_for(self, b: AnyBlock) -> Bool:
        """Grows dead bushes (Go `SoilFor`)."""
        var k = b.kind
        return k == HASH_DEAD_BUSH
