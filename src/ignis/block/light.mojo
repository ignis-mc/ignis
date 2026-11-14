"""`Light`, ported from Dragonfly `server/block/light.go`.

Go's `replaceable` and `flowingWaterDisplacer` helpers come with `world.Tx`
and liquids.

TODO(world-runtime): SideClosed.
"""

from ..world.block import Block, LightDiffuser, LightEmitter
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .hash import HASH_LIGHT
from .model.empty import Empty as EmptyModel


struct Light(
    Block,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    LightEmitter,
    ModelledBlock,
):
    """An invisible block that can produce any light level."""

    comptime BASE_HASH: UInt64 = HASH_LIGHT
    """Go `hashLight`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    var level: Int
    """The light level the block emits, 0 to 15."""

    def __init__(out self, *, level: Int = 0):
        """Creates the block; omitted fields take Go zero values."""
        self.level = level

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState(String(t"minecraft:light_block_{self.level}"))

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return UInt64(self.level)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Light(level=Int(hash & 0xFF))

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for level in range(16):
            out.append(Light(level=level))
        return out^

    def light_emission_level(self) -> UInt8:
        """Returns the light the block emits (Go `LightEmissionLevel`)."""
        return UInt8(self.level)

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem(String(t"minecraft:light_block_{self.level}"), 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        var out = List[Self]()
        for i in range(16):
            out.append(Self(level=i))
        return out^
