"""`Composter`, ported from Dragonfly `server/block/composter.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): InsertItem, ExtractItem, Model, SideClosed, Activate,
fill, ScheduledTick, FlammabilityInfo, FuelInfo, the break handler,
EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .hash import HASH_COMPOSTER


struct Composter(
    Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser
):
    """A block that turns organic items into bone meal."""

    comptime BASE_HASH: UInt64 = HASH_COMPOSTER
    """Go `hashComposter`."""

    var level: Int
    """How full the composter is, 0 to 8."""

    def __init__(out self, *, level: Int = 0):
        """Creates the block; omitted fields take Go zero values.

        Args:
            level: How full the composter is, 0 to 8.
        """
        self.level = level

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
            "minecraft:composter",
            Properties().with_int("composter_fill_level", Int32(self.level)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.level)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return Composter(level=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for level in range(9):
            out.append(Composter(level=level))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.6, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
