"""`Cactus`, ported from Dragonfly `server/block/cactus.go`.

TODO(world-runtime): UseOnBlock, EntityInside, DamageSource, CanDisplace,
SideClosed, Model and the drops.
"""

from ..item.item import Compostable
from ..world.block import (
    Block,
    LightDiffuser,
    NeighbourUpdateTicker,
    RandomTicker,
)
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
from .hash import AnyBlock, HASH_CACTUS
from .model.cactus import Cactus as CactusModel
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face
from .block import face_solid_at, is_air
from .dirt import supports_vegetation


struct Cactus(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    NeighbourUpdateTicker,
    RandomTicker,
):
    """A plant block that generates naturally in dry areas and causes damage."""

    comptime BASE_HASH: UInt64 = HASH_CACTUS
    """Go `hashCactus`."""
    comptime ModelType = CactusModel
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
            "minecraft:cactus",
            Properties().with_int("age", Int32(self.age)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.age)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Cactus(age=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for age in range(16):
            out.append(Cactus(age=age))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.4, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> CactusModel:
        """Returns the model of the block (Go `Model`)."""
        return CactusModel()

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.5

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:cactus", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks where it cannot grow (Go `NeighbourUpdateTick`)."""
        if not _cactus_can_grow_here(pos, tx, True):
            break_block(self, pos, tx)

    def random_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """Grows a block taller every 16 ticks (Go `RandomTick`)."""
        var c = self.copy()
        if c.age < 15:
            c.age += 1
        elif c.age == 15:
            c.age = 0
            if _cactus_can_grow_here(pos.side(Face.DOWN), tx, False):
                for y in range(1, 3):
                    var p = pos.add(Pos(0, y, 0))
                    if is_air(tx, p):
                        tx.set_block(p, Cactus())
                        break
                    elif not tx.block_as[Cactus](p):
                        break
        tx.set_block(pos, c)


def _cactus_can_grow_here[
    T: WorldTypes
](pos: Pos, mut tx: World[T], recursive: Bool) -> Bool:
    # Go `Cactus.canGrowHere`: air on every side and soil below.
    for face in [Face.NORTH, Face.EAST, Face.SOUTH, Face.WEST]:
        if not is_air(tx, pos.side(face)):
            return False
    if recursive and tx.block_as[Cactus](pos.side(Face.DOWN)):
        return _cactus_can_grow_here(pos.side(Face.DOWN), tx, recursive)
    return supports_vegetation(
        AnyBlock(Cactus()), tx.block(pos.side(Face.DOWN)), tx
    )
