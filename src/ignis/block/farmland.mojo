"""`Farmland`, ported from Dragonfly `server/block/farmland.go`.

TODO(world-runtime): SoilFor, NeighbourUpdateTick, RandomTick (with hydrated),
EntityLand and the drops.
"""

from ..world.block import Block, NeighbourUpdateTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    SHOVEL_EFFECTIVE,
    break_block,
    break_block_no_drops,
    new_break_info,
)
from .hash import (
    AnyBlock,
    HASH_DEAD_BUSH,
    HASH_DOUBLE_FLOWER,
    HASH_DOUBLE_TALL_GRASS,
    HASH_FARMLAND,
    HASH_FERN,
    HASH_FLOWER,
    HASH_NETHER_SPROUTS,
    HASH_PINK_PETALS,
    HASH_RED_SHRUB,
    HASH_SAPLING,
    HASH_SHORT_GRASS,
)
from .model.tilled_grass import TilledGrass as TilledGrassModel
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import face_solid_at, is_air
from .dirt import Dirt, Soil


struct Farmland(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    NeighbourUpdateTicker,
    Soil,
):
    """A block that crops are grown on, created by using a hoe on dirt or grass.
    """

    comptime BASE_HASH: UInt64 = HASH_FARMLAND
    """Go `hashFarmland`."""
    comptime ModelType = TilledGrassModel
    """The model type (Go `Model`)."""

    var hydration: Int
    """How hydrated the farmland is, 0 to 7."""

    def __init__(out self, *, hydration: Int = 0):
        """Creates the block; omitted fields take Go zero values."""
        self.hydration = hydration

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:farmland",
            Properties().with_int("moisturized_amount", Int32(self.hydration)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.hydration)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Farmland(hydration=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for hydration in range(8):
            out.append(Farmland(hydration=hydration))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.6, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> TilledGrassModel:
        """Returns the model of the block (Go `Model`)."""
        return TilledGrassModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:farmland", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Turns into dirt under a solid face (Go `NeighbourUpdateTick`)."""
        if face_solid_at(tx, pos.side(Face.UP), Face.DOWN):
            tx.set_block(pos, Dirt())

    def soil_for(self, b: AnyBlock) -> Bool:
        """Grows plants and saplings (Go `SoilFor`)."""
        var k = b.kind
        return (
            k == HASH_SHORT_GRASS
            or k == HASH_FERN
            or k == HASH_DOUBLE_TALL_GRASS
            or k == HASH_FLOWER
            or k == HASH_DOUBLE_FLOWER
            or k == HASH_NETHER_SPROUTS
            or k == HASH_PINK_PETALS
            or k == HASH_DEAD_BUSH
            or k == HASH_SAPLING
            or k == HASH_RED_SHRUB
        )
