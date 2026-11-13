"""`Campfire`, ported from Dragonfly `server/block/campfire.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the `Items [4]CampfireItem` field, Model, SideClosed,
Activate, UseOnBlock, Splash, Ignite, Extinguish, Tick, NeighbourUpdateTick,
EntityInside, DecodeNBT, EncodeNBT, the drops (charcoal or soul soil) and
break handler, FlammabilityInfo, EncodeItem.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
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


struct Campfire(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    LightEmitter,
    ModelledBlock,
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
        """Creates the block; omitted fields take Go zero values.

        Args:
            facing: The direction the campfire faces.
            extinguished: Whether the campfire is extinguished.
            type: The type of fire of the campfire.
        """
        self.facing = facing
        self.extinguished = extinguished
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks.

        Args:
            other: The block to compare with.

        Returns:
            True if both are in the same state.
        """
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            The name and properties.
        """
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
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(Int(self.facing))
            | (UInt64(1) if self.extinguished else UInt64(0)) << 2
            | UInt64(self.type.uint8()) << 3
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Campfire(
            facing=Direction(Int(hash & 0x3)),
            extinguished=(hash >> 2) & 0x1 != 0,
            type=FireType(Int((hash >> 3) & 0x1)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for d in directions():
            for f in fire_types():
                out.append(Campfire(facing=d, type=f, extinguished=True))
                out.append(Campfire(facing=d, type=f))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(2, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        if self.extinguished:
            return 0
        return self.type.light_level()

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> CampfireModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return CampfireModel()
