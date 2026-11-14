"""`InvisibleBedrock`, ported from Dragonfly
`server/block/invisible_bedrock.go`.
"""

from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .hash import HASH_INVISIBLE_BEDROCK
from .model.solid import Solid as SolidModel


struct InvisibleBedrock(
    Block, Equatable, ImplicitlyCopyable, Item, LightDiffuser, ModelledBlock
):
    """An indestructible, solid block, similar to a barrier."""

    comptime BASE_HASH: UInt64 = HASH_INVISIBLE_BEDROCK
    """Go `hashInvisibleBedrock`."""
    comptime ModelType = SolidModel
    """The model type (Go `Model`)."""

    def __init__(out self):
        """Creates the block (Go `InvisibleBedrock{}`)."""
        pass

    def __eq__(self, other: Self) -> Bool:
        """Compares two blocks."""
        return self.hash() == other.hash()

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:invisible_bedrock")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return InvisibleBedrock()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [InvisibleBedrock()]

    def light_diffusion_level(self) -> UInt8:
        """Returns the light the block takes away (Go
        `LightDiffusionLevel`)."""
        return 0

    def model(self) -> SolidModel:
        """Returns the model of the block (Go `Model`)."""
        return SolidModel()

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:invisible_bedrock", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `register.go`)."""
        return [Self()]
