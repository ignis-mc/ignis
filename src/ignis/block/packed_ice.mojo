"""`PackedIce`, ported from Dragonfly `server/block/packed_ice.go`.

TODO(world-runtime): Instrument, Friction and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    BreakInfo,
    Breakable,
    Dropper,
    PICKAXE_EFFECTIVE,
    new_break_info,
)
from .hash import HASH_PACKED_ICE
from .model.solid import Solid as SolidModel
from ..item.stack import Stack
from ..item.tool import ToolInfo


struct PackedIce(
    Block,
    Breakable,
    Dropper,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
):
    """An opaque solid block variant of ice that does not melt."""

    comptime BASE_HASH: UInt64 = HASH_PACKED_ICE
    """Go `hashPackedIce`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `PackedIce{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `Instrument`)."""
        return Instrument.CHIMES

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:packed_ice")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return PackedIce()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [PackedIce()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.5, ALWAYS_HARVESTABLE, PICKAXE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:packed_ice", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]

    def drops(self, tool: ToolInfo, silk_touch: Bool) -> List[Stack]:
        """Drops itself only with silk touch (Go `silkTouchOnlyDrop`)."""
        if silk_touch:
            return [Stack(self, 1)]
        return []
