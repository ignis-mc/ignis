"""`InfestedDeepslate`, ported from Dragonfly
`server/block/infested_deepslate.go`.

TODO(world-runtime): UseOnBlock, the `silkTouchOnlyDrop` drops and the
silverfish spawn.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..world.block import Block
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
from .cube.axis import Axis, axes
from .hash import HASH_INFESTED_DEEPSLATE
from .model.solid import Solid as SolidModel


struct InfestedDeepslate(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
):
    """A deepslate block that hides a silverfish."""

    comptime BASE_HASH: UInt64 = HASH_INFESTED_DEEPSLATE
    """Go `hashInfestedDeepslate`."""
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

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `flute`)."""
        return Instrument.FLUTE

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:infested_deepslate",
            Properties().with_string("pillar_axis", String(self.axis)),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(Int(self.axis))

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return InfestedDeepslate(axis=Axis(Int(hash & 0x3)))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for axis in axes():
            out.append(InfestedDeepslate(axis=axis))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            1.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(0.75)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:infested_deepslate", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
