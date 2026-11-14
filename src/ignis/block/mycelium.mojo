"""`Mycelium`, ported from Dragonfly `server/block/mycelium.go`.

TODO(world-runtime): SoilFor, RandomTick, Shovel and the drops.
"""

from ..world.block import Block, RandomTicker
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
from .hash import (
    AnyBlock,
    HASH_BAMBOO,
    HASH_BAMBOO_SAPLING,
    HASH_DEAD_BUSH,
    HASH_DOUBLE_FLOWER,
    HASH_DOUBLE_TALL_GRASS,
    HASH_FERN,
    HASH_FLOWER,
    HASH_MYCELIUM,
    HASH_NETHER_SPROUTS,
    HASH_PINK_PETALS,
    HASH_RED_SHRUB,
    HASH_SHORT_GRASS,
    HASH_SUGAR_CANE,
)
from .model.solid import Solid as SolidModel
from .dirt import Soil, spread_dirt
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face


struct Mycelium(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    RandomTicker,
    Soil,
):
    """A spreading dirt-type block found in mushroom fields."""

    comptime BASE_HASH: UInt64 = HASH_MYCELIUM
    """Go `hashMycelium`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `Mycelium{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:mycelium")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Mycelium()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Mycelium()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.6, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:mycelium", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def soil_for(self, b: AnyBlock) -> Bool:
        """Grows plants, sugar cane and bamboo (Go `SoilFor`)."""
        var k = b.kind
        return (
            k == HASH_SHORT_GRASS
            or k == HASH_FERN
            or k == HASH_DOUBLE_TALL_GRASS
            or k == HASH_FLOWER
            or k == HASH_DOUBLE_FLOWER
            or k == HASH_NETHER_SPROUTS
            or k == HASH_PINK_PETALS
            or k == HASH_SUGAR_CANE
            or k == HASH_DEAD_BUSH
            or k == HASH_BAMBOO_SAPLING
            or k == HASH_BAMBOO
            or k == HASH_RED_SHRUB
        )

    def random_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Spreads onto dirt around it, or dies in the dark (Go `RandomTick`).
        """
        spread_dirt(self, pos, tx, -2)
