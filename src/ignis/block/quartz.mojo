"""`Quartz`, `ChiseledQuartz`, `QuartzPillar`, ported from Dragonfly
`server/block/quartz.go`.

TODO(world-runtime): QuartzPillar.UseOnBlock, EncodeItem, SmeltInfo and the
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
from .hash import HASH_CHISELED_QUARTZ, HASH_QUARTZ, HASH_QUARTZ_PILLAR


struct Quartz(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A mineral block used only for decoration."""

    comptime BASE_HASH: UInt64 = HASH_QUARTZ
    """Go `hashQuartz`."""

    var smooth: Bool
    """Whether the quartz is smooth quartz."""

    def __init__(out self, *, smooth: Bool = False):
        """Creates the block; omitted fields take Go zero values.

        Args:
            smooth: Whether the quartz is smooth quartz.
        """
        self.smooth = smooth

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
            "minecraft:smooth_quartz" if self.smooth else "minecraft:quartz_block"
        )
        return BlockState(name, Properties().with_string("pillar_axis", "y"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(1) if self.smooth else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Quartz(smooth=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [Quartz(), Quartz(smooth=True)]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        if self.smooth:
            return new_break_info(
                2, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
            ).with_blast_resistance(6)
        return new_break_info(0.8, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)


struct ChiseledQuartz(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A chiseled variant of quartz."""

    comptime BASE_HASH: UInt64 = HASH_CHISELED_QUARTZ
    """Go `hashChiseledQuartz`."""

    def __init__(out self):
        """Creates the block (Go `ChiseledQuartz{}`)."""
        pass

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
            "minecraft:chiseled_quartz_block",
            Properties().with_string("pillar_axis", "y"),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return ChiseledQuartz()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        return [ChiseledQuartz()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.8, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)


struct QuartzPillar(Block, Breakable, Equatable, ImplicitlyCopyable):
    """A pillar variant of quartz."""

    comptime BASE_HASH: UInt64 = HASH_QUARTZ_PILLAR
    """Go `hashQuartzPillar`."""

    var axis: Axis
    """The axis the pillar faces."""

    def __init__(out self, *, axis: Axis = Axis.Y):
        """Creates the block; omitted fields take Go zero values.

        Args:
            axis: The axis the pillar faces.
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
            "minecraft:quartz_pillar",
            Properties().with_string("pillar_axis", String(self.axis)),
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
        return QuartzPillar(axis=Axis(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for axis in axes():
            out.append(QuartzPillar(axis=axis))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.8, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)
