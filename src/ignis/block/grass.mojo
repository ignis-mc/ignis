"""Grass blocks, ported from Dragonfly `server/block/grass.go`.

TODO(world-runtime): BoneMeal, Till and Shovel.
"""

from ..item.item import Compostable
from ..world.block import Block, RandomTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from ..item.stack import Stack
from ..item.tool import ToolInfo
from .dirt import Dirt, Soil, spread_dirt
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    Dropper,
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
    HASH_GRASS,
    HASH_NETHER_SPROUTS,
    HASH_PINK_PETALS,
    HASH_RED_SHRUB,
    HASH_SAPLING,
    HASH_SHORT_GRASS,
    HASH_SUGAR_CANE,
)
from .model.solid import Solid as SolidModel
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face


@fieldwise_init
struct Grass(
    Block,
    Breakable,
    Compostable,
    Dropper,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    RandomTicker,
    Soil,
):
    """Grass blocks generate abundantly across the surface of the world."""

    comptime BASE_HASH: UInt64 = HASH_GRASS
    """Go `hashGrass`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:grass_block")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Grass()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `RegisterBlock(Grass{})`)."""
        return [Grass()]

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`): 0.3."""
        return 0.3

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:grass_block", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `RegisterItem` calls
        in `register.go`)."""
        return [Grass()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.6, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def drops(self, tool: ToolInfo, silk_touch: Bool) -> List[Stack]:
        """Drops dirt, itself with silk touch (Go `silkTouchOneOf`)."""
        if silk_touch:
            return [Stack(self, 1)]
        return [Stack(Dirt(), 1)]

    def soil_for(self, b: AnyBlock) -> Bool:
        """Grows plants, sugar cane, bamboo and saplings (Go `SoilFor`)."""
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
            or k == HASH_SAPLING
            or k == HASH_RED_SHRUB
        )

    def random_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Spreads onto dirt around it, or dies in the dark (Go `RandomTick`).
        """
        spread_dirt(self, pos, tx, -3)
