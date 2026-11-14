"""`Loom`, ported from Dragonfly `server/block/loom.go`.

TODO(world-runtime): Activate, UseOnBlock, FlammabilityInfo and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .block import horizontal_direction
from .break_info import (
    ALWAYS_HARVESTABLE,
    AXE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.direction import Direction, directions
from .hash import HASH_LOOM
from .model.solid import Solid as SolidModel


struct Loom(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
):
    """A block used to apply patterns on banners."""

    comptime BASE_HASH: UInt64 = HASH_LOOM
    """Go `hashLoom`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var facing: Direction
    """The direction the loom faces."""

    def __init__(out self, *, facing: Direction = Direction.NORTH):
        """Creates the block; omitted fields take Go zero values."""
        self.facing = facing

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bass`)."""
        return Instrument.BASS

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:loom",
            Properties().with_int(
                "direction", Int32(Int(horizontal_direction(self.facing)))
            ),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.facing))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Loom(facing=Direction(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for facing in directions():
            out.append(Loom(facing=facing))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(2.5, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:loom", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
