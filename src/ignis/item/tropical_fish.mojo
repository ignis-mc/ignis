"""TropicalFish, ported from Dragonfly `server/item/tropical_fish.go`.

TODO(port): `Consume`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct TropicalFish(Equatable, ImplicitlyCopyable, Item):
    """A food item that cannot be cooked."""

    comptime BASE_HASH: UInt64 = item_hash("TropicalFish")
    """`item_hash("TropicalFish")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:tropical_fish", 0)

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
