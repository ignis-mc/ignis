"""`Carpet`, ported from Dragonfly `server/block/carpet.go`.

Go's `sourceWaterDisplacer` makes carpets a `LiquidDisplacer`; that trait
comes with liquids.

TODO(world-runtime): SideClosed, HasLiquidDrops, NeighbourUpdateTick,
UseOnBlock, FlammabilityInfo and the drops.
"""

from ..item.colour import Colour, colours
from ..world.block import (
    Block,
    LightDiffuser,
    LiquidDisplacer,
    NeighbourUpdateTicker,
)
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    break_block,
    break_block_no_drops,
    new_break_info,
)
from .hash import AnyBlock, HASH_CARPET
from .model.carpet import Carpet as CarpetModel
from .liquid import LiquidRemovable, source_water_can_displace
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import face_solid_at, is_air


struct Carpet(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    LiquidRemovable,
    ModelledBlock,
    NeighbourUpdateTicker,
):
    """A colourful decorative block that can be placed on top of any block."""

    comptime BASE_HASH: UInt64 = HASH_CARPET
    """Go `hashCarpet`."""
    comptime ModelType = CarpetModel
    """The model type (Go `Model`)."""

    var colour: Colour
    """The colour of the carpet."""

    def __init__(out self, *, colour: Colour = Colour.WHITE):
        """Creates the block; omitted fields take Go zero values."""
        self.colour = colour

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(String(t"minecraft:{self.colour}_carpet"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.colour.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Carpet(colour=Colour(Int(hash & 0xF)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for colour in colours():
            out.append(Carpet(colour=colour))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.1, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> CarpetModel:
        """Returns the model of the block (Go `Model`)."""
        return CarpetModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.colour}_carpet"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for c in colours():
            out.append(Self(colour=c))
        return out^

    def has_liquid_drops(self) -> Bool:
        """Returns True (Go `HasLiquidDrops`)."""
        return True

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks over air (Go `NeighbourUpdateTick`)."""
        if is_air(tx, pos.side(Face.DOWN)):
            break_block(self, pos, tx)
