"""`Cinnabar`, ported from Dragonfly `server/block/cinnabar.go`.

TODO(world-runtime): the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

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
from .hash import HASH_CINNABAR
from .model.solid import Solid as SolidModel


struct Cinnabar(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
):
    """A decorative mineral block."""

    comptime BASE_HASH: UInt64 = HASH_CINNABAR
    """Go `hashCinnabar`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var chiseled: Bool
    """Whether the cinnabar is chiseled."""

    def __init__(out self, *, chiseled: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.chiseled = chiseled

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.chiseled:
            return BlockState("minecraft:chiseled_cinnabar")
        return BlockState("minecraft:cinnabar")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.chiseled else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Cinnabar(chiseled=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Cinnabar(), Cinnabar(chiseled=True)]

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
        if self.chiseled:
            return EncodedItem("minecraft:chiseled_cinnabar", 0)
        return EncodedItem("minecraft:cinnabar", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self(), Self(chiseled=True)]
