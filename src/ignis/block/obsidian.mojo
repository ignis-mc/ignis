"""`Obsidian`, ported from Dragonfly `server/block/obsidian.go`.

TODO(world-runtime): Frame, SupportsEndCrystal and the drops.
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
    HARVEST_LEVEL_DIAMOND,
    PICKAXE_EFFECTIVE,
    new_break_info,
    pickaxe_harvestable_from,
)
from .hash import HASH_OBSIDIAN
from .model.solid import Solid as SolidModel


struct Obsidian(
    Block,
    Breakable,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    LightEmitter,
    ModelledBlock,
):
    """A dark purple block known for its high blast resistance and strength, most commonly found when
    water flows over lava."""

    comptime BASE_HASH: UInt64 = HASH_OBSIDIAN
    """Go `hashObsidian`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var crying: Bool
    """Whether the obsidian is crying obsidian."""

    def __init__(out self, *, crying: Bool = False):
        """Creates the block; omitted fields take Go zero values."""
        self.crying = crying

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        if self.crying:
            return BlockState("minecraft:crying_obsidian")
        return BlockState("minecraft:obsidian")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.crying else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Obsidian(crying=hash & 0x1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Obsidian(crying=True), Obsidian()]

    def break_info(self) -> BreakInfo:
        """Returns the break info (Go `BreakInfo`)."""
        return new_break_info(
            35,
            pickaxe_harvestable_from(HARVEST_LEVEL_DIAMOND),
            PICKAXE_EFFECTIVE,
        ).with_blast_resistance(1200)

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return 10 if self.crying else 0

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        if self.crying:
            return EncodedItem("minecraft:crying_obsidian", 0)
        return EncodedItem("minecraft:obsidian", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Obsidian(crying=True), Obsidian()]
