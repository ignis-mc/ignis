"""Dirt, ported from Dragonfly `server/block/dirt.go`.

TODO(world-runtime): Till, Shovel.
"""

from ..world.block import Block
from ..world.world import World, WorldTypes
from .cube.face import Face
from .cube.pos import Pos
from .hash import (
    AnyBlock,
    HASH_BAMBOO,
    HASH_BAMBOO_SAPLING,
    HASH_DEAD_BUSH,
    HASH_DIRT,
    HASH_DOUBLE_FLOWER,
    HASH_DOUBLE_TALL_GRASS,
    HASH_FERN,
    HASH_FLOWER,
    HASH_NETHER_SPROUTS,
    HASH_PINK_PETALS,
    HASH_RED_SHRUB,
    HASH_SAPLING,
    HASH_SHORT_GRASS,
    HASH_SUGAR_CANE,
)
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
from .model.solid import Solid as SolidModel


trait Soil:
    """A block that can support vegetation (Go `Soil`)."""

    def soil_for(self, b: AnyBlock) -> Bool:
        """Reports whether the vegetation `b` can grow on it (Go
        `SoilFor`)."""
        ...


def supports_vegetation[
    T: WorldTypes
](vegetation: AnyBlock, below: UInt32, mut tx: World[T]) -> Bool:
    """Reports whether the vegetation can exist on the block `below` (Go
    `supportsVegetation`)."""
    var br = tx.block_registry()
    return T.Blocks.soil_for(
        br[].kind(below), br[].state_hash(below), vegetation
    )


def spread_dirt[
    B: Block, T: WorldTypes
](b: B, pos: Pos, mut tx: World[T], min_y: Int):
    """Turns grass or mycelium in the dark into dirt, or spreads it to dirt
    around it (Go `spreadDirt`)."""
    var above_light = tx.light(pos.side(Face.UP))
    if above_light < 4:
        tx.set_block(pos, Dirt())
        return
    if above_light < 9:
        return
    # Only 28 bits are needed, 7 per attempt.
    var n = tx.rand().uint32()
    for _ in range(4):
        var x = Int(n % 3)
        var y = Int((n >> 2) % 5)
        var z = Int((n >> 5) % 3)
        n >>= 7
        var spread_pos = pos.add(Pos(x - 1, y + min_y, z - 1))
        if tx.light(spread_pos.side(Face.UP)) < 4:
            continue
        var d = tx.block_as[Dirt](spread_pos)
        if not d or d.value().coarse:
            continue
        tx.set_block(spread_pos, b)


@fieldwise_init
struct Dirt(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
    Soil,
):
    """A block found abundantly in most biomes under a layer of grass."""

    comptime BASE_HASH: UInt64 = HASH_DIRT
    """Go `hashDirt`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var coarse: Bool
    """Whether the dirt is coarse dirt; grass does not spread onto it."""

    def __init__(out self):
        """Creates plain dirt (Go `Dirt{}`)."""
        self.coarse = False

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.coarse:
            return BlockState("minecraft:coarse_dirt")
        return BlockState("minecraft:dirt")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.coarse else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Dirt(coarse=hash & 1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Dirt(coarse=True), Dirt()]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.coarse:
            return EncodedItem("minecraft:coarse_dirt", 0)
        return EncodedItem("minecraft:dirt", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `RegisterItem` calls
        in `register.go`)."""
        return [Dirt(coarse=True), Dirt()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.5, ALWAYS_HARVESTABLE, SHOVEL_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def soil_for(self, b: AnyBlock) -> Bool:
        """Grows grass and the like unless coarse, and flowers, sugar cane,
        bamboo and saplings (Go `SoilFor`)."""
        var k = b.kind
        if (
            k == HASH_SHORT_GRASS
            or k == HASH_FERN
            or k == HASH_DOUBLE_TALL_GRASS
            or k == HASH_DEAD_BUSH
            or k == HASH_RED_SHRUB
        ):
            return not self.coarse
        return (
            k == HASH_FLOWER
            or k == HASH_DOUBLE_FLOWER
            or k == HASH_NETHER_SPROUTS
            or k == HASH_PINK_PETALS
            or k == HASH_SUGAR_CANE
            or k == HASH_BAMBOO_SAPLING
            or k == HASH_BAMBOO
            or k == HASH_SAPLING
        )
