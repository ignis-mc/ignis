"""`WoodFence`, ported from Dragonfly `server/block/wood_fence.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): NeighbourUpdateTick, DeriveState, SideClosed, Model,
FlammabilityInfo, FuelInfo, EncodeItem and the drops.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .connections import Connections, all_connections
from .hash import HASH_WOOD_FENCE
from .model.fence import Fence as FenceModel
from .wood_type import WoodType, wood_types


struct WoodFence(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A wooden fence that blocks the way of entities, but may be jumped over by them.
    """

    comptime BASE_HASH: UInt64 = HASH_WOOD_FENCE
    """Go `hashWoodFence`."""
    comptime ModelType = FenceModel
    """The model type (Go `Model`)."""

    var wood: WoodType
    """The type of wood."""
    var connections: Connections
    """The sides the fence connects on."""

    def __init__(
        out self,
        *,
        wood: WoodType = WoodType.OAK,
        connections: Connections = Connections(),
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            wood: The type of wood.
            connections: The sides the fence connects on.
        """
        self.wood = wood
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
            String(t"minecraft:{self.wood}_fence"),
            self.connections.properties(Properties()),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.wood.uint8()) | UInt64(self.connections.uint8()) << 4

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return WoodFence(
            wood=WoodType(Int(hash & 0xF)),
            connections=Connections(bits=Int((hash >> 4) & 0xF)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for wood in wood_types():
            for connections in all_connections():
                out.append(WoodFence(wood=wood, connections=connections))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(
            2, ALWAYS_HARVESTABLE, AXE_EFFECTIVE
        ).with_blast_resistance(3)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> FenceModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return FenceModel(wood=True)
