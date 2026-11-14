"""`ConcretePowder`, ported from Dragonfly
`server/block/concrete_powder.go`.

TODO(world-runtime): Solidifies, NeighbourUpdateTick, the falling behaviour of
`gravityAffected` and the drops.
"""

from ..item.colour import Colour, colours
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    SHOVEL_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_CONCRETE_POWDER
from .model.solid import Solid as SolidModel


struct ConcretePowder(
    Block, Breakable, Equatable, ImplicitlyCopyable, Item, ModelledBlock
):
    """A gravity affected block that comes in 16 different colours."""

    comptime BASE_HASH: UInt64 = HASH_CONCRETE_POWDER
    """Go `hashConcretePowder`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var colour: Colour
    """The colour of the concrete powder."""

    def __init__(out self, *, colour: Colour = Colour.WHITE):
        """Creates the block; omitted fields take Go zero values."""
        self.colour = colour

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(String(t"minecraft:{self.colour}_concrete_powder"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.colour.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return ConcretePowder(colour=Colour(Int(hash & 0xF)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for colour in colours():
            out.append(ConcretePowder(colour=colour))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.5, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(
            String(t"minecraft:{self.colour}_concrete_powder"), 0
        )

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for c in colours():
            out.append(Self(colour=c))
        return out^
