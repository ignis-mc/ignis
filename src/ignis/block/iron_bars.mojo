"""`IronBars`, ported from Dragonfly `server/block/iron_bars.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): the drops.
"""

from ..world.block import NeighbourUpdateTicker
from ..world.block_source import BlockSource
from ..world.world import World, WorldTypes
from .block import StateDeriver
from .connections import calculate_connections
from .cube.pos import Pos


from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .connections import Connections, all_connections
from .hash import HASH_IRON_BARS
from .model.thin import Thin as ThinModel
from ..world.block import LiquidDisplacer
from .hash import AnyBlock
from .liquid import source_water_can_displace


struct IronBars(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    ModelledBlock,
    NeighbourUpdateTicker,
    StateDeriver,
):
    """A pane-like block made of iron."""

    comptime BASE_HASH: UInt64 = HASH_IRON_BARS
    """Go `hashIronBars`."""
    comptime ModelType = ThinModel
    """The model type (Go `Model`)."""

    var connections: Connections
    """The sides the bars connect on."""

    def __init__(out self, *, connections: Connections = Connections()):
        """Creates the block; omitted fields take Go zero values."""
        self.connections = connections

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:iron_bars", self.connections.properties(Properties())
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.connections.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return IronBars(connections=Connections(bits=Int(hash & 0xF)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for connections in all_connections():
            out.append(IronBars(connections=connections))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(6)

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

    def model(self) -> ThinModel:
        """Returns the model of the block (Go `Model`)."""
        return ThinModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:iron_bars", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)
