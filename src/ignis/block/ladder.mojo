"""`Ladder`, ported from Dragonfly `server/block/ladder.go`.

Go's `sourceWaterDisplacer` makes it a `LiquidDisplacer`; that trait comes
with liquids.

TODO(world-runtime): NeighbourUpdateTick, UseOnBlock, EntityInside, SideClosed,
Model and the drops.
"""

from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import (
    Block,
    LightDiffuser,
    LiquidDisplacer,
    NeighbourUpdateTicker,
)
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .block import UNKNOWN_DIRECTION, face_solid_at, is_air, light_diffuser_at
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    break_block,
    break_block_no_drops,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import AnyBlock, HASH_LADDER
from .model.ladder import Ladder as LadderModel
from .liquid import source_water_can_displace
from ..world.world import World, WorldTypes
from .cube.pos import Pos
from .cube.face import Face


struct Ladder(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LiquidDisplacer,
    ModelledBlock,
    NeighbourUpdateTicker,
):
    """A wooden block used for climbing walls either vertically or horizontally.
    """

    comptime BASE_HASH: UInt64 = HASH_LADDER
    """Go `hashLadder`."""
    comptime ModelType = LadderModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the ladder faces; `UNKNOWN_DIRECTION` encodes as 0."""

    def __init__(out self, *, facing: Direction = Direction.NORTH):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var facing = Int32(0)
        if self.facing != UNKNOWN_DIRECTION:
            facing = Int32(Int(self.facing) + 2)
        return BlockState(
            "minecraft:ladder",
            Properties().with_int("facing_direction", facing),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.facing))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Ladder(facing=Direction(Int(hash & 0x7)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for f in directions():
            out.append(Ladder(facing=f))
        out.append(Ladder(facing=UNKNOWN_DIRECTION))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.4, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> LadderModel:
        """Returns the model of the block (Go `Model`)."""
        return LadderModel(facing=self.facing)

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:ladder", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def can_displace(self, b: AnyBlock) -> Bool:
        """Holds water sources (Go `sourceWaterDisplacer`)."""
        return source_water_can_displace(b)

    def neighbour_update_tick[
        T: WorldTypes
    ](self, pos: Pos, changed_neighbour: Pos, mut tx: World[T]):
        """Breaks when the block behind it lets light through (Go
        `NeighbourUpdateTick`)."""
        if light_diffuser_at(tx, pos.side(self.facing.face().opposite())):
            break_block(self, pos, tx)
