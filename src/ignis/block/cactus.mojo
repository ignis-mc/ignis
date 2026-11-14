"""`Cactus`, ported from Dragonfly `server/block/cactus.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, RandomTick, EntityInside,
DamageSource, CanDisplace, SideClosed, Model and the drops.
"""

from ..item.item import Compostable
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_CACTUS
from .model.cactus import Cactus as CactusModel


struct Cactus(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
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
