"""`Portal`, ported from Dragonfly `server/block/portal.go`.

TODO(world-runtime): Model, Portal, NeighbourUpdateTick and EntityInside.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .cube.axis import Axis
from .hash import HASH_PORTAL
from .model.portal import Portal as PortalModel
from .liquid import LiquidRemovable


struct Portal(
    Block,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    LightEmitter,
    LiquidRemovable,
    ModelledBlock,
):
    """The translucent part of the nether portal that teleports the player to and from the nether.
    """

    comptime BASE_HASH: UInt64 = HASH_PORTAL
    """Go `hashPortal`."""
    comptime ModelType = PortalModel
    """The model type (Go `Model`)."""

    var axis: Axis
    """The axis the portal faces."""

    def __init__(out self, *, axis: Axis = Axis.Y):
        """Creates the block; omitted fields take Go zero values."""
        self.axis = axis

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:portal",
            Properties().with_string("portal_axis", String(self.axis)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.axis))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Portal(axis=Axis(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Portal(axis=Axis.X), Portal(axis=Axis.Z)]

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 11

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> PortalModel:
        """Returns the model of the block (Go `Model`)."""
        return PortalModel(axis=self.axis)

    def has_liquid_drops(self) -> Bool:
        """Returns False (Go `HasLiquidDrops`)."""
        return False
