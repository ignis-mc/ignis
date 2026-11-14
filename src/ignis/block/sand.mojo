"""`Sand`, ported from Dragonfly `server/block/sand.go`.

TODO(world-runtime): the falling behaviour of `gravityAffected` and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..item.smelting_info import SmeltInfo, Smeltable
from ..item.stack import Stack
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
from .glass import Glass
from .hash import (
    AnyBlock,
    HASH_BAMBOO,
    HASH_BAMBOO_SAPLING,
    HASH_CACTUS,
    HASH_DEAD_BUSH,
    HASH_SAND,
    HASH_SUGAR_CANE,
)
from .model.solid import Solid as SolidModel
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import gravity_fall
from .dirt import Soil


struct Sand(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
    NeighbourUpdateTicker,
    Smeltable,
    Soil,
):
    """A block affected by gravity, found in deserts and beaches."""

    comptime BASE_HASH: UInt64 = HASH_SAND
    """Go `hashSand`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var red: Bool
    """Whether the sand is red sand."""

    def __init__(out self, *, red: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.red = red

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `snare`)."""
        return Instrument.SNARE

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.red:
            return BlockState("minecraft:red_sand")
        return BlockState("minecraft:sand")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.red else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Sand(red=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Sand(red=True), Sand()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.5, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.red:
            return EncodedItem("minecraft:red_sand", 0)
        return EncodedItem("minecraft:sand", 0)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`)."""
        return SmeltInfo(Stack(Glass(), 1), 0.1)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Sand(red=True), Sand()]

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Falls when nothing holds it up (Go `NeighbourUpdateTick`)."""
        gravity_fall(self, pos, tx)

    def soil_for(self, b: AnyBlock) -> Bool:
        """Grows cacti, dead bushes, sugar cane and bamboo (Go `SoilFor`)."""
        var k = b.kind
        return (
            k == HASH_CACTUS
            or k == HASH_DEAD_BUSH
            or k == HASH_SUGAR_CANE
            or k == HASH_BAMBOO_SAPLING
            or k == HASH_BAMBOO
        )
