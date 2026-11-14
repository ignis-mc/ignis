"""`Campfire`, ported from Dragonfly `server/block/campfire.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `Items [4]CampfireItem` field, Model, SideClosed,
Activate, UseOnBlock, Splash, Ignite, Extinguish, Tick, NeighbourUpdateTick,
EntityInside, the drops (charcoal or soul soil) and break handler,
FlammabilityInfo.
"""

from minecraft.nbt.tree import Tag, Tree

from ..world.block import Block, LightDiffuser, LightEmitter, NBTer
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .fire_type import FireType, fire_types
from .hash import HASH_CAMPFIRE
from .model.campfire import Campfire as CampfireModel
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct Campfire(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    LiquidDisplacer,
    ModelledBlock,
    NBTer,
):
    """A block that can be used to cook food, pacify bees, act as a spread-proof light source,
    smoke signal or damaging trap block."""

    comptime BASE_HASH: UInt64 = HASH_CAMPFIRE
    """Go `hashCampfire`."""
    comptime ModelType = CampfireModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the campfire faces."""
    var extinguished: Bool
    """Whether the campfire is extinguished."""
    var type: FireType
    """The type of fire of the campfire."""

    def __init__(
        out self,
        *,
        facing: Direction = Direction.NORTH,
        extinguished: Bool = False,
        type: FireType = FireType.NORMAL,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing
        self.extinguished = extinguished
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var name = "minecraft:campfire"
        if self.type == FireType.SOUL:
            name = "minecraft:soul_campfire"
        return BlockState(
            name,
            Properties()
            .with_string("minecraft:cardinal_direction", String(self.facing))
            .with_bool("extinguished", self.extinguished),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.extinguished else UInt64(0)) << 2
            | UInt64(self.type.uint8()) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Campfire(
            facing=Direction(Int(hash & 0x3)),
            extinguished=(hash >> 2) & 0x1 != 0,
            type=FireType(Int((hash >> 3) & 0x1)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for d in directions():
            for f in fire_types():
                out.append(Campfire(facing=d, type=f, extinguished=True))
                out.append(Campfire(facing=d, type=f))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(2, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        if self.extinguished:
            return 0
        return self.type.light_level()

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> CampfireModel:
        """Returns the model of the block (Go `Model`)."""
        return CampfireModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.type == FireType.SOUL:
            return EncodedItem("minecraft:soul_campfire", 0)
        return EncodedItem("minecraft:campfire", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for f in fire_types():
            out.append(Self(type=f))
        return out^

    def encode_nbt(self, mut tag: Tree, root: Tag) raises:
        """Writes the block entity NBT (Go `EncodeNBT`)."""
        _ = tag.put_string(root, "id", "Campfire")
        # TODO(world-runtime): Item1-4 and ItemTime1-4 of the cooking items.

    def decode_nbt(self, tag: Tree, root: Tag) raises -> Self:
        """Returns the block with the NBT decoded into it (Go `DecodeNBT`)."""
        # TODO(world-runtime): the cooking items.
        return self.copy()

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
