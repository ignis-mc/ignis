"""`Flower`, ported from Dragonfly `server/block/flower.go`.

TODO(world-runtime): EntityInside (wither rose), UseOnBlock, BoneMeal,
FlammabilityInfo and the drops.
"""

from ..item.item import Compostable
from ..world.block import Block, LightDiffuser, NeighbourUpdateTicker
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
from .flower_type import FlowerType, flower_types
from .hash import AnyBlock, HASH_FLOWER
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import face_solid_at, is_air
from .dirt import supports_vegetation


struct Flower(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidRemovable,
    ModelledBlock,
    NeighbourUpdateTicker,
):
    """A non-solid plant that occur in a variety of shapes and colours."""

    comptime BASE_HASH: UInt64 = HASH_FLOWER
    """Go `hashFlower`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var type: FlowerType
    """The type of flower."""

    def __init__(out self, *, type: FlowerType = FlowerType.DANDELION):
        """Creates the block; omitted fields take Go zero values."""
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(String(t"minecraft:{self.type}"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Flower(type=FlowerType(Int(hash & 0xF)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for type in flower_types():
            out.append(Flower(type=type))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.65

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.type}"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for f in flower_types():
            out.append(Self(type=f))
        return out^

    def has_liquid_drops(self) -> Bool:
        """Returns True (Go `HasLiquidDrops`)."""
        return True

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks without soil below (Go `NeighbourUpdateTick`)."""
        if not supports_vegetation(
            AnyBlock(self), tx.block(pos.side(Face.DOWN)), tx
        ):
            break_block(self, pos, tx)
