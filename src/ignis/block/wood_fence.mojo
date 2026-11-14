"""`WoodFence`, ported from Dragonfly `server/block/wood_fence.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): Model, FlammabilityInfo
and the drops.
"""

from ..world.block import NeighbourUpdateTicker
from ..world.block_source import BlockSource
from ..world.world import World, WorldTypes
from .block import StateDeriver
from .connections import calculate_connections
from .cube.pos import Pos


from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
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
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct WoodFence(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    ModelledBlock,
    NeighbourUpdateTicker,
    StateDeriver,
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
        """Creates the block; omitted fields take Go zero values."""
        self.wood = wood
        self.connections = connections

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bass`)."""
        return Instrument.BASS

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            String(t"minecraft:{self.wood}_fence"),
            self.connections.properties(Properties()),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.wood.uint8()) | UInt64(self.connections.uint8()) << 4

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return WoodFence(
            wood=WoodType(Int(hash & 0xF)),
            connections=Connections(bits=Int((hash >> 4) & 0xF)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for wood in wood_types():
            for connections in all_connections():
                out.append(WoodFence(wood=wood, connections=connections))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            2, ALWAYS_HARVESTABLE, AXE_EFFECTIVE
        ).with_blast_resistance(3)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def derive_state[S: BlockSource](self, pos: Pos, src: S) -> Self:
        """Returns the block with the sides it connects to at `pos` (Go
        `DeriveState`)."""
        var b = self
        b.connections = calculate_connections(self.model(), src, pos)
        return b

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Updates the connections when a neighbour changes (Go
        `NeighbourUpdateTick`)."""
        var c = calculate_connections(self.model(), tx.source(), pos)
        if c != self.connections:
            var b = self
            b.connections = c
            tx.set_block(pos, b)

    def model(self) -> FenceModel:
        """Returns the model of the block (Go `Model`)."""
        return FenceModel(wood=True)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.wood}_fence"), 0)

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`); none for nether wood."""
        if not self.wood.flammable():
            return FuelInfo()
        return FuelInfo(15000)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for v in wood_types():
            out.append(WoodFence(wood=v))
        return out^

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
