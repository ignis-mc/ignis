"""Honeycomb, ported from Dragonfly `server/item/honeycomb.go`.

TODO(port): `UseOnBlock`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct Honeycomb(Equatable, ImplicitlyCopyable, Item):
    """An item obtained from bee nests and beehives."""

    comptime BASE_HASH: UInt64 = item_hash("Honeycomb")
    """`item_hash("Honeycomb")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:honeycomb", 0)

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
