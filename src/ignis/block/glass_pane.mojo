"""`GlassPane`, ported from Dragonfly `server/block/glass_pane.go`.

Go's `sourceWaterDisplacer` makes panes a `LiquidDisplacer`; that trait
comes with liquids.

TODO(world-runtime): NeighbourUpdateTick, DeriveState, SideClosed, the
`silkTouchOnlyDrop` drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .connections import Connections, all_connections
from .hash import HASH_GLASS_PANE


struct GlassPane(
    Block, Breakable, Equatable, ImplicitlyCopyable, LightDiffuser
):
    """A transparent block that can be used as a more efficient alternative to glass blocks.
    """

    comptime BASE_HASH: UInt64 = HASH_GLASS_PANE
    """Go `hashGlassPane`."""

    var connections: Connections
    """The sides the pane connects on."""

    def __init__(out self, *, connections: Connections = Connections()):
        """Creates the block; omitted fields take Go zero values.

        Args:
            connections: The sides the pane connects on.
        """
        self.connections = connections

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
            "minecraft:glass_pane", self.connections.properties(Properties())
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.connections.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return GlassPane(connections=Connections(bits=Int(hash & 0xF)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for connections in all_connections():
            out.append(GlassPane(connections=connections))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0.3, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0
