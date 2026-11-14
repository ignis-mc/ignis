"""Scute, ported from Dragonfly `server/item/scute.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct Scute(Equatable, ImplicitlyCopyable, Item):
    """An item that baby turtles drop when they grow into adults."""

    comptime BASE_HASH: UInt64 = item_hash("Scute")
    """`item_hash("Scute")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:turtle_scute", 0)

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
