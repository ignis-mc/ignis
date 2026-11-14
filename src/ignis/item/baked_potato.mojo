"""BakedPotato, ported from Dragonfly `server/item/baked_potato.go`.

TODO(port): `Consume`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import Compostable


@fieldwise_init
struct BakedPotato(Compostable, Equatable, ImplicitlyCopyable, Item):
    """A food item that can be eaten by the player."""

    comptime BASE_HASH: UInt64 = item_hash("BakedPotato")
    """`item_hash("BakedPotato")`."""

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.85

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:baked_potato", 0)

    def hash(self) -> UInt64:
        """Returns the item hash; the type has one value."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Self()]
