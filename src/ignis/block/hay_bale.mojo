"""`HayBale`, ported from Dragonfly `server/block/hay_bale.go`.

TODO(world-runtime): Instrument, EntityLand, UseOnBlock, FlammabilityInfo and
the drops.
"""

from ..item.item import Compostable
from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    HOE_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.axis import Axis, axes
from .hash import HASH_HAY_BALE
from .model.solid import Solid as SolidModel


struct HayBale(
    Block,
    Breakable,
    Compostable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    ModelledBlock,
):
    """A decorative, flammable block that can also be used to feed horses, breed llamas, reduce fall damage, and extend campfire smokes.
    """

    comptime BASE_HASH: UInt64 = HASH_HAY_BALE
    """Go `hashHayBale`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var axis: Axis
    """The axis the block faces."""

    def __init__(out self, *, axis: Axis = Axis.Y):
        """Creates the block; omitted fields take Go zero values."""
        self.axis = axis

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:hay_block",
            Properties()
            .with_string("pillar_axis", String(self.axis))
            .with_int("deprecated", 0),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.axis))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return HayBale(axis=Axis(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for axis in axes():
            out.append(HayBale(axis=axis))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.5, ALWAYS_HARVESTABLE, HOE_EFFECTIVE)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.85

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:hay_block", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
