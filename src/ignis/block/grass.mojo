"""Grass blocks, ported from Dragonfly `server/block/grass.go`.

`RandomTick`, `BoneMeal`, `SoilFor`, `Till`, `Shovel` and `BreakInfo` follow
with `world.Tx`, the item package and the plant blocks they refer to.
"""

from ..world.block import Block
from ..world.block_state import BlockState
from ..world.item import EncodedItem, Item
from .hash import HASH_GRASS


@fieldwise_init
struct Grass(Block, Equatable, ImplicitlyCopyable, Item):
    """Grass blocks generate abundantly across the surface of the world."""

    comptime BASE_HASH: UInt64 = HASH_GRASS
    """Go `hashGrass`."""

    def encode_block(self) -> BlockState:
        """Encodes the block (Go `EncodeBlock`).

        Returns:
            `minecraft:grass_block` without properties.
        """
        return BlockState("minecraft:grass_block")

    def hash(self) -> UInt64:
        """Returns the state hash (Go `Hash`).

        Returns:
            0: grass has no state.
        """
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the block from its state hash.

        Args:
            hash: The state hash.

        Returns:
            Grass.
        """
        return Grass()

    @staticmethod
    def all_states() -> List[Self]:
        """Returns the registered values (Go `RegisterBlock(Grass{})`).

        Returns:
            Grass.
        """
        return [Grass()]

    def encode_item(self) -> EncodedItem:
        """Encodes the block as an item (Go `EncodeItem`).

        Returns:
            `minecraft:grass_block`, metadata 0.
        """
        return EncodedItem("minecraft:grass_block", 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the values registered as items (Go `RegisterItem` calls
        in `register.go`).

        Returns:
            Grass.
        """
        return [Grass()]
