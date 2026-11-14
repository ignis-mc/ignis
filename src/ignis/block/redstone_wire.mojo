"""`RedstoneWire`, ported from Dragonfly `server/block/redstone_wire.go`.

TODO(world-runtime): UseOnBlock, NeighbourUpdateTick, RedstoneUpdate,
RedstoneSource, RedstonePower, RedstoneStrongPower, the connection calculation,
diagonal wire updates, Model, HasLiquidDrops, the break handler and the drops.
"""

from ..item.armour_trim import ArmourTrimMaterial
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    NOTHING_EFFECTIVE,
    new_break_info,
)
from .hash import HASH_REDSTONE_WIRE
from .model.empty import Empty as EmptyModel
from .wire_connection import WireConnections, all_wire_connections
from .liquid import LiquidRemovable


struct RedstoneWire(
    ArmourTrimMaterial,
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidRemovable,
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
        """Creates the block; omitted fields take Go zero values."""
        self.power = power
        self.connections = connections

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:redstone_wire",
            self.connections.properties(Properties()).with_int(
                "redstone_signal", Int32(min(max(self.power, 0), 15))
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.power) | UInt64(self.connections.uint8()) << 8

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return RedstoneWire(
            power=Int(hash & 0xFF),
            connections=WireConnections(bits=Int((hash >> 8) & 0x7F)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for power in range(16):
            for connections in all_wire_connections():
                out.append(RedstoneWire(power=power, connections=connections))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def trim_material(self) -> StaticString:
        """Returns the trim material identifier (Go `TrimMaterial`)."""
        return "redstone"

    def material_colour(self) -> StaticString:
        """Returns the trim text colour (Go `MaterialColour`, `text.Redstone`).
        """
        return "§m"

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:redstone", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def has_liquid_drops(self) -> Bool:
        """Returns True (Go `HasLiquidDrops`)."""
        return True
