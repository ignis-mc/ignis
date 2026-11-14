"""`StringBlock`, ported from Dragonfly `server/block/string.go`.

Go names the type `String`; here it is `StringBlock` so that it does not
shadow the built-in `String` wherever it is imported.

TODO(world-runtime): UseOnBlock, EntityInside, NeighbourUpdateTick, tripwire
hook logic, HasLiquidDrops, Model and the drops.
"""

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
from .connections import Connections, all_connections
from .hash import HASH_STRING
from .model.empty import Empty as EmptyModel


struct StringBlock(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
):
    """A tripwire: string placed as a block (Go `String`)."""

    comptime BASE_HASH: UInt64 = HASH_STRING
    """Go `hashString`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var attached: Bool
    """Whether the string is connected to tripwire hooks."""
    var disarmed: Bool
    """Whether the string was cut with shears."""
    var powered: Bool
    """Whether an entity is on the string."""
    var suspended: Bool
    """Whether the string is suspended in the air."""
    var connections: Connections
    """The sides the string connects on."""

    def __init__(
        out self,
        *,
        attached: Bool = False,
        disarmed: Bool = False,
        powered: Bool = False,
        suspended: Bool = False,
        connections: Connections = Connections(),
    ):
        """Creates the block; omitted fields take Go zero values.

        Args:
            attached: Whether the string is connected to tripwire hooks.
            disarmed: Whether the string was cut with shears.
            powered: Whether an entity is on the string.
            suspended: Whether the string is suspended in the air.
            connections: The sides the string connects on.
        """
        self.attached = attached
        self.disarmed = disarmed
        self.powered = powered
        self.suspended = suspended
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
            "minecraft:trip_wire",
            self.connections.properties(Properties())
            .with_byte("attached_bit", UInt8(self.attached))
            .with_byte("disarmed_bit", UInt8(self.disarmed))
            .with_byte("powered_bit", UInt8(self.powered))
            .with_byte("suspended_bit", UInt8(self.suspended)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            The fields packed into bits.
        """
        return (
            (UInt64(1) if self.attached else UInt64(0))
            | (UInt64(1) if self.disarmed else UInt64(0)) << 1
            | (UInt64(1) if self.powered else UInt64(0)) << 2
            | (UInt64(1) if self.suspended else UInt64(0)) << 3
            | UInt64(self.connections.uint8()) << 4
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The block.
        """
        return StringBlock(
            attached=hash & 0x1 != 0,
            disarmed=(hash >> 1) & 0x1 != 0,
            powered=(hash >> 2) & 0x1 != 0,
            suspended=(hash >> 3) & 0x1 != 0,
            connections=Connections(bits=Int((hash >> 4) & 0xF)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Every state of the block.
        """
        var out = List[Self]()
        for meta in range(16):
            for c in all_connections():
                out.append(
                    StringBlock(
                        powered=meta & 1 != 0,
                        suspended=meta & 2 != 0,
                        attached=meta & 4 != 0,
                        disarmed=meta & 8 != 0,
                        connections=c,
                    )
                )
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

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:string", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
