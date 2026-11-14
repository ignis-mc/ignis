"""`EndPortal`, ported from Dragonfly `server/block/end_portal.go`.

TODO(world-runtime): Model, Portal and EntityInside.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from .hash import HASH_END_PORTAL
from .model.empty import Empty as EmptyModel
from .liquid import LiquidRemovable


struct EndPortal(
    Block,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    LightEmitter,
    LiquidRemovable,
    ModelledBlock,
):
    """A portal that transports an entity to the End."""

    comptime BASE_HASH: UInt64 = HASH_END_PORTAL
    """Go `hashEndPortal`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `EndPortal{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:end_portal")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return EndPortal()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [EndPortal()]

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 15

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def has_liquid_drops(self) -> Bool:
        """Returns False (Go `HasLiquidDrops`)."""
        return False
