"""`Coral`, ported from Dragonfly `server/block/coral.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): UseOnBlock, HasLiquidDrops, NeighbourUpdateTick,
ScheduledTick, SideClosed and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .coral_type import CoralType, coral_types
from .hash import HASH_CORAL
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct Coral(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    LiquidRemovable,
    ModelledBlock,
):
    """A non-solid block that comes in 5 variants."""

    comptime BASE_HASH: UInt64 = HASH_CORAL
    """Go `hashCoral`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var type: CoralType
    """The type of coral."""
    var dead: Bool
    """Whether the coral is dead."""

    def __init__(
        out self, *, type: CoralType = CoralType.TUBE, dead: Bool = False
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.type = type
        self.dead = dead

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var dead = "dead_" if self.dead else ""
        return BlockState(String(t"minecraft:{dead}{self.type}_coral"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(self.type.uint8())
            | (UInt64(1) if self.dead else UInt64(0)) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Coral(
            type=CoralType(Int(hash & 0x7)), dead=(hash >> 3) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for dead in [True, False]:
            for t in coral_types():
                out.append(Coral(type=t, dead=dead))
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
        if self.dead:
            return EncodedItem(String(t"minecraft:dead_{self.type}_coral"), 0)
        return EncodedItem(String(t"minecraft:{self.type}_coral"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for dead in [True, False]:
            for t in coral_types():
                out.append(Self(type=t, dead=dead))
        return out^

    def has_liquid_drops(self) -> Bool:
        """Returns False (Go `HasLiquidDrops`)."""
        return False

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
