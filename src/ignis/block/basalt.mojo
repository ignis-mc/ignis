"""`Basalt`, ported from Dragonfly `server/block/basalt.go`.

TODO(world-runtime): UseOnBlock and the `oneOf` drops.
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
from .hash import HASH_BASALT
from .model.solid import Solid as SolidModel


struct Basalt(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
):
    """A type of igneous rock found in the nether."""

    comptime BASE_HASH: UInt64 = HASH_BASALT
    """Go `hashBasalt`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var polished: Bool
    """Whether the basalt is polished."""
    var axis: Axis
    """The axis the basalt faces."""

    def __init__(out self, *, polished: Bool = False, axis: Axis = Axis.Y):
        """Creates the block; omitted fields take Go zero values."""
        self.polished = polished
        self.axis = axis

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        var name = (
            "minecraft:polished_basalt" if self.polished else "minecraft:basalt"
        )
        return BlockState(
            name, Properties().with_string("pillar_axis", String(self.axis))
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return (UInt64(1) if self.polished else UInt64(0)) | UInt64(
            Int(self.axis)
        ) << 1

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Basalt(
            polished=hash & 0x1 != 0, axis=Axis(Int((hash >> 1) & 0x3))
        )

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for axis in axes():
            out.append(Basalt(polished=False, axis=axis))
            out.append(Basalt(polished=True, axis=axis))
        return out^

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            1.25, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE
        ).with_blast_resistance(4.2)

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.polished:
            return EncodedItem("minecraft:polished_basalt", 0)
        return EncodedItem("minecraft:basalt", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self(polished=True), Self()]
