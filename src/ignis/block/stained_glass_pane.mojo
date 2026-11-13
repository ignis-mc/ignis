"""`StainedGlassPane`, ported from Dragonfly
`server/block/stained_glass_pane.go`.

Go's `sourceWaterDisplacer` makes panes a `LiquidDisplacer`; that trait
comes with liquids.

TODO(world-runtime): NeighbourUpdateTick, DeriveState, SideClosed, the
`silkTouchOnlyDrop` drops.
"""

from ..item.colour import Colour, colours
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .connections import Connections, all_connections
from .hash import HASH_STAINED_GLASS_PANE
from .model.thin import Thin as ThinModel


struct StainedGlassPane(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A transparent block that can be used as a more efficient alternative to glass blocks.
    """

    comptime BASE_HASH: UInt64 = HASH_STAINED_GLASS_PANE
    """Go `hashStainedGlassPane`."""
    comptime ModelType = ThinModel
    """The model type (Go `Model`)."""

    var colour: Colour
    """The colour of the pane."""
    var connections: Connections
    """The sides the pane connects on."""

    def __init__(
        out self,
        *,
        colour: Colour = Colour.WHITE,
        connections: Connections = Connections(),
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            colour: The colour of the pane.
            connections: The sides the pane connects on.
        """
        self.colour = colour
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
            String(t"minecraft:{self.colour}_stained_glass_pane"),
            self.connections.properties(Properties()),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            UInt64(self.colour.uint8()) | UInt64(self.connections.uint8()) << 4
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return StainedGlassPane(
            colour=Colour(Int(hash & 0xF)),
            connections=Connections(bits=Int((hash >> 4) & 0xF)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for colour in colours():
            for connections in all_connections():
                out.append(
                    StainedGlassPane(colour=colour, connections=connections)
                )
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

    def model(self) -> ThinModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return ThinModel()
