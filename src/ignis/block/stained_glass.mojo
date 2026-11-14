"""`StainedGlass`, ported from Dragonfly `server/block/stained_glass.go`.

TODO(world-runtime): the `silkTouchOnlyDrop` drops.
"""

from ..item.colour import Colour, colours
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    new_break_info,
)
from .hash import HASH_STAINED_GLASS
from .model.solid import Solid as SolidModel


struct StainedGlass(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """A decorative, fully transparent solid block that is dyed into a different colour.
    """

    comptime BASE_HASH: UInt64 = HASH_STAINED_GLASS
    """Go `hashStainedGlass`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var colour: Colour
    """The colour of the stained glass."""

    def __init__(out self, *, colour: Colour = Colour.WHITE):
        """Creates the block; omitted fields take Go zero values."""
        self.colour = colour

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(String(t"minecraft:{self.colour}_stained_glass"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.colour.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return StainedGlass(colour=Colour(Int(hash & 0xF)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for colour in colours():
            out.append(StainedGlass(colour=colour))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.3, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.colour}_stained_glass"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in colours():
            out.append(StainedGlass(colour=v))
        return out^
