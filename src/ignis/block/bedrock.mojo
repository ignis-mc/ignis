"""Bedrock, ported from Dragonfly `server/block/bedrock.go`."""

from ..world.sound.instrument import Instrument
from .block import Instrumented

from ..world.block import Block
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .hash import HASH_BEDROCK
from .model.solid import Solid as SolidModel


@fieldwise_init
struct Bedrock(
    Block,
    Equatable,
    ImplicitlyCopyable,
    Instrumented,
    Item,
    ModelledBlock,
):
    """A block that is indestructible in survival."""

    comptime BASE_HASH: UInt64 = HASH_BEDROCK
    """Go `hashBedrock`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    var infinite_burning: Bool
    """Whether the bedrock burns forever, as under end crystals on the end
    pillars."""

    def __init__(out self):
        """Creates bedrock that does not burn (Go `Bedrock{}`)."""
        self.infinite_burning = False

    def instrument(self) -> Instrument:
        """Returns the instrument of note blocks above it (Go `bassDrum`)."""
        return Instrument.BASS_DRUM

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(
            "minecraft:bedrock",
            Properties().with_bool("infiniburn_bit", self.infinite_burning),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(1) if self.infinite_burning else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Bedrock(infinite_burning=hash & 1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Bedrock(infinite_burning=True), Bedrock()]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:bedrock", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `RegisterItem` calls
        in `register.go`)."""
        return [Bedrock()]

    def supports_end_crystal(self) -> Bool:
        """Reports whether an end crystal may be placed on the block."""
        return True

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()
