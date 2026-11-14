"""`CocoaBean`, ported from Dragonfly `server/block/cocoa_bean.go`.

TODO(world-runtime): BoneMeal, HasLiquidDrops, NeighbourUpdateTick, UseOnBlock,
RandomTick, Model and the drops.
"""

from ..item.item import Compostable
from ..world.block import Block, LightDiffuser, RandomTicker
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .block import horizontal_direction
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_COCOA_BEAN
from .model.cocoa_bean import CocoaBean as CocoaBeanModel
from .liquid import LiquidRemovable
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face


struct CocoaBean(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidRemovable,
    ModelledBlock,
    RandomTicker,
):
    """A crop block found in jungle biomes."""

    comptime BASE_HASH: UInt64 = HASH_COCOA_BEAN
    """Go `hashCocoaBean`."""
    comptime ModelType = CocoaBeanModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction from the cocoa bean to the log."""
    var age: Int
    """The stage of growth, 0 to 2; 2 is fully grown."""

    def __init__(
        out self, *, facing: Direction = Direction.NORTH, age: Int = 0
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.age = age

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:cocoa",
            Properties()
            .with_int("age", Int32(self.age))
            .with_int(
                "direction", Int32(Int(horizontal_direction(self.facing)))
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.facing)) | UInt64(self.age) << 2

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return CocoaBean(
            facing=Direction(Int(hash & 0x3)), age=Int((hash >> 2) & 0xFF)
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for facing in directions():
            for age in range(3):
                out.append(CocoaBean(facing=facing, age=age))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            0.2, ALWAYS_HARVESTABLE, AXE_EFFECTIVE
        ).with_blast_resistance(3)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> CocoaBeanModel:
        """Returns the model of the block (Go `Model`)."""
        return CocoaBeanModel(facing=self.facing, age=self.age)

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.65

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:cocoa_beans", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def has_liquid_drops(self) -> Bool:
        """Returns True (Go `HasLiquidDrops`)."""
        return True

    def random_tick[T: WorldTypes](self, pos: Pos, mut tx: World[T]):
        """May grow (Go `RandomTick`)."""
        if self.age < 2 and tx.rand().int_n(5) == 0:
            var c = self.copy()
            c.age += 1
            tx.set_block(pos, c)
