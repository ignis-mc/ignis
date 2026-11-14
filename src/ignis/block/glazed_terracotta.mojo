"""`GlazedTerracotta`, ported from Dragonfly
`server/block/glazed_terracotta.go`.

TODO(world-runtime): UseOnBlock and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..item.colour import Colour, colours
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .block import UNKNOWN_DIRECTION
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_GLAZED_TERRACOTTA
from .model.solid import Solid as SolidModel


struct GlazedTerracotta(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
):
    """A vibrant solid block that comes in the 16 regular dye colours."""

    comptime BASE_HASH: UInt64 = HASH_GLAZED_TERRACOTTA
    """Go `hashGlazedTerracotta`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var colour: Colour
    """The colour of the glazed terracotta."""
    var facing: Direction
    """The direction the top of the texture faces; `UNKNOWN_DIRECTION` encodes as 0."""

    def __init__(
        out self,
        *,
        colour: Colour = Colour.WHITE,
        facing: Direction = Direction.NORTH,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.colour = colour
        self.facing = facing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var facing = Int32(0)
        if self.facing != UNKNOWN_DIRECTION:
            facing = Int32(2 + Int(self.facing))
        return BlockState(
            String(
                t"minecraft:{self.colour.silver_string()}_glazed_terracotta"
            ),
            Properties().with_int("facing_direction", facing),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.colour.uint8()) | UInt64(Int(self.facing)) << 4

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return GlazedTerracotta(
            colour=Colour(Int(hash & 0xF)),
            facing=Direction(Int((hash >> 4) & 0x7)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        var dirs = directions()
        dirs.append(UNKNOWN_DIRECTION)
        for d in dirs:
            for c in colours():
                out.append(GlazedTerracotta(colour=c, facing=d))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(1.4, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(
            String(
                t"minecraft:{self.colour.silver_string()}_glazed_terracotta"
            ),
            0,
        )

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in colours():
            out.append(GlazedTerracotta(colour=v))
        return out^
