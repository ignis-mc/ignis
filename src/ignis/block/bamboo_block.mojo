"""`BambooBlock`, ported from Dragonfly `server/block/bamboo_block.go`.

TODO(world-runtime): UseOnBlock, Strip, FlammabilityInfo and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..item.smelting_info import Fuel, FuelInfo
from ..world.block import Block
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
from .cube.axis import Axis, axes
from .hash import HASH_BAMBOO_BLOCK
from .model.solid import Solid as SolidModel


struct BambooBlock(
    Block,
    Breakable,
    Equatable,
    Fuel,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
):
    """A block made from bamboo, which can be stripped."""

    comptime BASE_HASH: UInt64 = HASH_BAMBOO_BLOCK
    """Go `hashBambooBlock`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var axis: Axis
    """The axis the block faces."""
    var stripped: Bool
    """Whether the block has been stripped."""

    def __init__(out self, *, axis: Axis = Axis.Y, stripped: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.axis = axis
        self.stripped = stripped

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bass`)."""
        return Instrument.BASS

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var name = (
            "minecraft:stripped_bamboo_block" if self.stripped else "minecraft:bamboo_block"
        )
        return BlockState(
            name, Properties().with_string("pillar_axis", String(self.axis))
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (
            UInt64(Int(self.axis))
            | (UInt64(1) if self.stripped else UInt64(0)) << 2
        )

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return BambooBlock(
            axis=Axis(Int(hash & 0x3)), stripped=(hash >> 2) & 0x1 != 0
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for axis in axes():
            out.append(BambooBlock(axis=axis))
            out.append(BambooBlock(axis=axis, stripped=True))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(2.0, ALWAYS_HARVESTABLE, AXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.stripped:
            return EncodedItem("minecraft:stripped_bamboo_block", 0)
        return EncodedItem("minecraft:bamboo_block", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self(), Self(stripped=True)]
