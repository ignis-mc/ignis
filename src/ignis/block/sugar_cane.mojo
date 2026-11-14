"""`SugarCane`, ported from Dragonfly `server/block/sugar_cane.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, RandomTick, BoneMeal,
canGrowHere and the drops.
"""

from ..world.block import Block, LightDiffuser, NeighbourUpdateTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
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
from .hash import AnyBlock, HASH_SUGAR_CANE
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import face_solid_at, is_air
from .dirt import supports_vegetation
from .water import Water


struct SugarCane(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidRemovable,
    ModelledBlock,
    NeighbourUpdateTicker,
):
    """A plant block that generates naturally near water."""

    comptime BASE_HASH: UInt64 = HASH_SUGAR_CANE
    """Go `hashSugarCane`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var age: Int
    """The growth state, 0 to 15."""

    def __init__(out self, *, age: Int = 0):
        """Creates the block; omitted fields take Go zero values."""
        self.age = age

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:reeds",
            Properties().with_int("age", Int32(self.age)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.age)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return SugarCane(age=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for age in range(16):
            out.append(SugarCane(age=age))
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

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:sugar_cane", 0)

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
        """Breaks where it cannot grow (Go `NeighbourUpdateTick`)."""
        if not _sugar_cane_can_grow_here(pos, tx, True):
            break_block(self, pos, tx)


def _sugar_cane_can_grow_here[
    T: WorldTypes
](pos: Pos, mut tx: World[T], recursive: Bool) -> Bool:
    # Go `SugarCane.canGrowHere`: soil below with water next to it.
    if recursive and tx.block_as[SugarCane](pos.side(Face.DOWN)):
        return _sugar_cane_can_grow_here(pos.side(Face.DOWN), tx, recursive)
    if supports_vegetation(
        AnyBlock(SugarCane()), tx.block(pos.side(Face.DOWN)), tx
    ):
        var br = tx.block_registry()
        for face in [Face.NORTH, Face.EAST, Face.SOUTH, Face.WEST]:
            var l = tx.liquid(pos.side(face).side(Face.DOWN))
            if l and br[].is_block[Water](l.value()):
                return True
    return False
