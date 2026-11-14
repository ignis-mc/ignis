"""Air, ported from Dragonfly `server/block/air.go`.

Go's `Air` embeds `empty` (model), `replaceable` and `transparent`. Mojo has
no embedding, so the methods those provide are written out where they are
ported: `transparent` is `LightDiffuser` returning 0 and `replaceable` is
`Replaceable`.
"""

from .block import Replaceable
from .hash import AnyBlock
from ..world.block import Block, LightDiffuser
from ..world.block_model import ModelledBlock
from ..world.block_state import BlockState
from ..world.dimension import Dimension, NETHER
from ..world.item import EncodedItem, Item
from .hash import HASH_AIR
from .model.empty import Empty as EmptyModel


@fieldwise_init
struct Air(
    Block,
    Equatable,
    ImplicitlyCopyable,
    Item,
    LightDiffuser,
    ModelledBlock,
    Replaceable,
):
    """The block present in otherwise empty space."""

    comptime BASE_HASH: UInt64 = HASH_AIR
    """Go `hashAir`."""
    comptime ModelType = EmptyModel
    """The model type (Go `Model`)."""

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`)."""
        return BlockState("minecraft:air")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`)."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash."""
        return Air()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `RegisterBlock(Air{})`)."""
        return [Air()]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:air", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `RegisterItem` calls
        in `register.go`)."""
        return [Air()]

    def light_diffusion_level(self) -> UInt8:
        """Air lets all light through (Go `transparent`)."""
        return 0

    def has_liquid_drops(self) -> Bool:
        """Reports whether the block drops as an item when liquid flows into
        it."""
        return False

    def portal_interior(self, target: Dimension) -> Bool:
        """Reports whether air may fill a portal frame for the target
        dimension before activation."""
        return target == NETHER

    def model(self) -> EmptyModel:
        """Returns the model of the block (Go `Model`)."""
        return EmptyModel()

    def replaceable_by(self, b: AnyBlock) -> Bool:
        """Any block replaces it (Go's embedded `replaceable`)."""
        return True
