"""`Gravel`, ported from Dragonfly `server/block/gravel.go`.

TODO(world-runtime): the falling behaviour of `gravityAffected` and the drops
(flint).
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..world.block import Block, NeighbourUpdateTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    SHOVEL_EFFECTIVE,
    new_break_info,
)
from .hash import AnyBlock, HASH_BAMBOO, HASH_BAMBOO_SAPLING, HASH_GRAVEL
from .model.solid import Solid as SolidModel
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import gravity_fall
from .dirt import Soil


struct Gravel(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
    NeighbourUpdateTicker,
    Soil,
):
    """A block affected by gravity."""

    comptime BASE_HASH: UInt64 = HASH_GRAVEL
    """Go `hashGravel`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `Gravel{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `snare`)."""
        return Instrument.SNARE

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:gravel")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Gravel()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Gravel()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.6, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:gravel", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Falls when nothing holds it up (Go `NeighbourUpdateTick`)."""
        gravity_fall(self, pos, tx)

    def soil_for(self, b: AnyBlock) -> Bool:
        """Grows bamboo (Go `SoilFor`)."""
        var k = b.kind
        return k == HASH_BAMBOO_SAPLING or k == HASH_BAMBOO
