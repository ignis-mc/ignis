"""`Froglight`, ported from Dragonfly `server/block/froglight.go`.

TODO(world-runtime): UseOnBlock and the drops.
"""

from ..world.block import Block, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .break_info import (
    ALWAYS_HARVESTABLE,
    NOTHING_EFFECTIVE,
    BreakInfo,
    Breakable,
    new_break_info,
)
from .cube.axis import Axis, axes
from .froglight_type import FroglightType, froglight_types
from .hash import HASH_FROGLIGHT
from .model.solid import Solid as SolidModel


struct Froglight(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightEmitter,
    ModelledBlock,
):
    """A luminous natural block that can be obtained if a frog eats a tiny magma cube.
    """

    comptime BASE_HASH: UInt64 = HASH_FROGLIGHT
    """Go `hashFroglight`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var type: FroglightType
    """The type of froglight."""
    var axis: Axis
    """The axis the froglight faces."""

    def __init__(
        out self,
        *,
        type: FroglightType = FroglightType.PEARLESCENT,
        axis: Axis = Axis.Y,
    ):
        """Creates the block; omitted fields take Go zero values."""
        self.type = type
        self.axis = axis

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            String(t"minecraft:{self.type}_froglight"),
            Properties().with_string("pillar_axis", String(self.axis)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.type.uint8()) | UInt64(Int(self.axis)) << 2

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Froglight(
            type=FroglightType(Int(hash & 0x3)),
            axis=Axis(Int((hash >> 2) & 0x3)),
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for axis in axes():
            for t in froglight_types():
                out.append(Froglight(type=t, axis=axis))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.3, ALWAYS_HARVESTABLE, NOTHING_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 15

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:{self.type}_froglight"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for t in froglight_types():
            out.append(Self(type=t))
        return out^
