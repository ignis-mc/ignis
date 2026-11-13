"""`RedstoneWire`, ported from Dragonfly `server/block/redstone_wire.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, RedstoneUpdate,
RedstoneSource, RedstonePower, RedstoneStrongPower, the connection
calculation and diagonal wire updates, Model, HasLiquidDrops, the break
handler, EncodeItem and the drops.
"""

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
from .hash import HASH_REDSTONE_WIRE
from .model.empty import Empty as EmptyModel
from .wire_connection import WireConnections, all_wire_connections


struct RedstoneWire(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    LightDiffuser,
    ModelledBlock,
):
    """A block used to transfer redstone power between blocks."""

    comptime BASE_HASH: UInt64 = HASH_REDSTONE_WIRE
    """Go `hashRedstoneWire`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var power: Int
    """The redstone power the wire carries, 0 to 15."""
    var connections: WireConnections
    """How the wire connects on each side."""

    def __init__(
        out self,
        *,
        power: Int = 0,
        connections: WireConnections = WireConnections(),
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            power: The redstone power the wire carries, 0 to 15.
            connections: How the wire connects on each side.
        """
        self.power = power
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
            "minecraft:redstone_wire",
            self.connections.properties(Properties()).with_int(
                "redstone_signal", Int32(min(max(self.power, 0), 15))
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return UInt64(self.power) | UInt64(self.connections.uint8()) << 8

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return RedstoneWire(
            power=Int(hash & 0xFF),
            connections=WireConnections(bits=Int((hash >> 8) & 0x7F)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for power in range(16):
            for connections in all_wire_connections():
                out.append(RedstoneWire(power=power, connections=connections))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`).

        Returns:
            The hardness, blast resistance and tools.
        """
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`).

        Returns:
            The diffusion level, 0 to 15.
        """
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`).

        Returns:
            The model.
        """
        return EmptyModel()
