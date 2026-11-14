"""`ShortGrass`, ported from Dragonfly `server/block/short_grass.go`.

Go's `replaceable` helper is `Replaceable`.

TODO(world-runtime): UseOnBlock, BoneMeal, FlammabilityInfo and the drops.
"""

from .block import Replaceable, face_solid_at, is_air
from .hash import AnyBlock, HASH_SHORT_GRASS
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
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .dirt import supports_vegetation


struct ShortGrass(
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
    Replaceable,
):
    """Vegetation blocks generated on grass."""

    comptime BASE_HASH: UInt64 = HASH_SHORT_GRASS
    """Go `hashShortGrass`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var double: Bool
    """Unused by Dragonfly: it is not part of the state."""

    def __init__(out self, *, double: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.double = double

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash() and self.double == other.double

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:short_grass")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return ShortGrass()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [ShortGrass()]

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

    def replaceable_by(self, b: AnyBlock) -> Bool:
        """Any block replaces it (Go's embedded `replaceable`)."""
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:short_grass", 0)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.65

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

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
