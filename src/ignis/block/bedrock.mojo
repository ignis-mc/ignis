"""Bedrock, ported from Dragonfly `server/block/bedrock.go`."""

from ..world.block import Block
from ..world.block_state import BlockState, Properties
from ..world.item import EncodedItem, Item
from .hash import HASH_BEDROCK


@fieldwise_init
struct Bedrock(Block, Equatable, ImplicitlyCopyable, Item):
    """A block that is indestructible in survival."""

    comptime BASE_HASH: UInt64 = HASH_BEDROCK
    """Go `hashBedrock`."""

    var infinite_burning: Bool
    """Whether the bedrock burns forever, as under end crystals on the end
    pillars."""

    def __init__(out self):
        """Creates bedrock that does not burn (Go `Bedrock{}`)."""
        self.infinite_burning = False

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            `minecraft:bedrock` with `infiniburn_bit`.
        """
        return BlockState(
            "minecraft:bedrock",
            Properties().with_bool("infiniburn_bit", self.infinite_burning),
        )

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            1 for burning bedrock, 0 otherwise.
        """
        return UInt64(1) if self.infinite_burning else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The bedrock.
        """
        return Bedrock(infinite_burning=hash & 1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Burning bedrock and bedrock.
        """
        return [Bedrock(infinite_burning=True), Bedrock()]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`).

        Returns:
            `minecraft:bedrock`, metadata 0.
        """
        return EncodedItem("minecraft:bedrock", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `RegisterItem` calls
        in `register.go`).

        Returns:
            Bedrock that does not burn.
        """
        return [Bedrock()]

    def supports_end_crystal(self) -> Bool:
        """Reports whether an end crystal may be placed on the block.

        Returns:
            True.
        """
        return True
