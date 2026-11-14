"""`Magma`, ported from Dragonfly `server/block/magma.go`.

TODO(world-runtime): EntityStepOn, MagmaDamageSource and the drops.
"""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..world.block import Block, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .break_info import (
    BreakInfo,
    Breakable,
    PICKAXE_EFFECTIVE,
    PICKAXE_HARVESTABLE,
    new_break_info,
)
from .hash import HASH_MAGMA
from .model.solid import Solid as SolidModel


struct Magma(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    LightEmitter,
    ModelledBlock,
):
    """A light-emitting block found in the nether that damages entities standing on it.
    """

    comptime BASE_HASH: UInt64 = HASH_MAGMA
    """Go `hashMagma`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `Magma{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:magma")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Magma()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Magma()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(0.5, PICKAXE_HARVESTABLE, PICKAXE_EFFECTIVE)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 3

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:magma", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
