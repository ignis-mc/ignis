"""Dirt, ported from Dragonfly `server/block/dirt.go`.

`SoilFor`, `Till`, `Shovel`, `BreakInfo` and `spreadDirt` follow with
`world.Tx`, the item package and the plant blocks they refer to.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .hash import HASH_DIRT


@fieldwise_init
struct Dirt(Block, Equatable, ImplicitlyCopyable, Item):
    """A block found abundantly in most biomes under a layer of grass."""

    comptime BASE_HASH: UInt64 = HASH_DIRT
    """Go `hashDirt`."""

    var coarse: Bool
    """Whether the dirt is coarse dirt; grass does not spread onto it."""

    def __init__(out self):
        """Creates plain dirt (Go `Dirt{}`)."""
        self.coarse = False

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            `minecraft:coarse_dirt` or `minecraft:dirt`, no properties.
        """
        if self.coarse:
            return BlockState("minecraft:coarse_dirt")
        return BlockState("minecraft:dirt")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            1 for coarse dirt, 0 otherwise.
        """
        return UInt64(1) if self.coarse else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            The dirt.
        """
        return Dirt(coarse=hash & 1 != 0)

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `register.go`).

        Returns:
            Coarse dirt and dirt.
        """
        return [Dirt(coarse=True), Dirt()]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`).

        Returns:
            `minecraft:coarse_dirt` or `minecraft:dirt`, metadata 0.
        """
        if self.coarse:
            return EncodedItem("minecraft:coarse_dirt", 0)
        return EncodedItem("minecraft:dirt", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `RegisterItem` calls
        in `register.go`).

        Returns:
            Coarse dirt and dirt.
        """
        return [Dirt(coarse=True), Dirt()]
