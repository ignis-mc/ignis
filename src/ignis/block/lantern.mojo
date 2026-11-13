"""`Lantern`, ported from Dragonfly `server/block/lantern.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): Model, NeighbourUpdateTick, UseOnBlock, SideClosed,
EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_state import BlockState, Properties
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .fire_type import FireType, fire_types
from .hash import HASH_LANTERN


struct Lantern(
    Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser, LightEmitter
):
    """A light emitting block."""

    comptime BASE_HASH: UInt64 = HASH_LANTERN
    """Go `hashLantern`."""

    var hanging: Bool
    """Whether the lantern hangs from a block."""
    var type: FireType
    """The type of fire in the lantern."""

    def __init__(
        out self, *, hanging: Bool = False, type: FireType = FireType.NORMAL
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            hanging: Whether the lantern hangs from a block.
            type: The type of fire in the lantern.
        """
        self.hanging = hanging
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
        var name = "minecraft:lantern"
        if self.type == FireType.SOUL:
            name = "minecraft:soul_lantern"
        return BlockState(name, Properties().with_bool("hanging", self.hanging))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (UInt64(1) if self.hanging else UInt64(0)) | UInt64(
            self.type.uint8()
        ) << 1

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Lantern(
            hanging=hash & 0x1 != 0, type=FireType(Int((hash >> 1) & 0x1))
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for f in fire_types():
            out.append(Lantern(hanging=False, type=f))
            out.append(Lantern(hanging=True, type=f))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(3.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`).

        Returns:
            The light level, 0 to 15.
        """
        return self.type.light_level()

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
