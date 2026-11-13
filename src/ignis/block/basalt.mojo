"""`Basalt`, ported from Dragonfly `server/block/basalt.go`.

TODO(world-runtime): UseOnBlock, EncodeItem, SmeltInfo and the `oneOf`
drops.
"""

from ..world.block import Block
from ..world.block_state import BlockState, Properties
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.axis import Axis, axes
from .hash import HASH_BASALT


struct Basalt(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A type of igneous rock found in the nether."""

    comptime BASE_HASH: UInt64 = HASH_BASALT
    """Go `hashBasalt`."""

    var polished: Bool
    """Whether the basalt is polished."""
    var axis: Axis
    """The axis the basalt faces."""

    def __init__(out self, *, polished: Bool = False, axis: Axis = Axis.Y):
        """Creates the block; omitted fields take Go zero values.

        Args:
            polished: Whether the basalt is polished.
            axis: The axis the basalt faces.
        """
        self.polished = polished
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
        var name = (
            "minecraft:polished_basalt" if self.polished else "minecraft:basalt"
        )
        return BlockState(
            name, Properties().with_string("pillar_axis", String(self.axis))
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (UInt64(1) if self.polished else UInt64(0)) | UInt64(
            Int(self.axis)
        ) << 1

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Basalt(
            polished=hash & 0x1 != 0, axis=Axis(Int((hash >> 1) & 0x3))
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for axis in axes():
            out.append(Basalt(polished=False, axis=axis))
            out.append(Basalt(polished=True, axis=axis))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            1.25, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(4.2)
