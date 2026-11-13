"""`Portal`, ported from Dragonfly `server/block/portal.go`.

TODO(world-runtime): Model, Portal, HasLiquidDrops, NeighbourUpdateTick,
EntityInside.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_state import BlockState, Properties
from .cube.axis import Axis
from .hash import HASH_PORTAL


struct Portal(
    Block, Equatable, ImplicitlyCopyable, LightDiffuser, LightEmitter
):
    """The translucent part of the nether portal that teleports the player to and from the nether.
    """

    comptime BASE_HASH: UInt64 = HASH_PORTAL
    """Go `hashPortal`."""

    var axis: Axis
    """The axis the portal faces."""

    def __init__(out self, *, axis: Axis = Axis.Y):
        """Creates the block; omitted fields take Go zero values.

        Args:
            axis: The axis the portal faces.
        """
        self.axis = axis

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
        return BlockState(
            "minecraft:portal",
            Properties().with_string("portal_axis", String(self.axis)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(Int(self.axis))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Portal(axis=Axis(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Portal(axis=Axis.X), Portal(axis=Axis.Z)]

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        return 11

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
