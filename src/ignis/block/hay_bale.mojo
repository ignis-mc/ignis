"""`HayBale`, ported from Dragonfly `server/block/hay_bale.go`.

TODO(world-runtime): Instrument, EntityLand, UseOnBlock, CompostChance,
FlammabilityInfo, EncodeItem and the drops.
"""

from ..world.block import Block
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    HOE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.axis import Axis, axes
from .hash import HASH_HAY_BALE


struct HayBale(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A decorative, flammable block that can also be used to feed horses, breed llamas, reduce fall damage, and extend campfire smokes.
    """

    comptime BASE_HASH: UInt64 = HASH_HAY_BALE
    """Go `hashHayBale`."""

    var axis: Axis
    """The axis the block faces."""

    def __init__(out self, *, axis: Axis = Axis.Y):
        """Creates the block; omitted fields take Go zero values.

        Args:
            axis: The axis the block faces.
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
            "minecraft:hay_block",
            Properties()
            .with_string("pillar_axis", String(self.axis))
            .with_int("deprecated", 0),
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
        return HayBale(axis=Axis(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for axis in axes():
            out.append(HayBale(axis=axis))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.5, ALWAYS_HARVESTABLE, HOE_EFFECTIVE)
