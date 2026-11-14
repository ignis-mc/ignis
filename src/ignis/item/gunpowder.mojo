"""Gunpowder, ported from Dragonfly `server/item/gunpowder.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct Gunpowder(Equatable, ImplicitlyCopyable, Item):
    """An item that is used for explosion-related recipes."""

    comptime BASE_HASH: UInt64 = item_hash("Gunpowder")
    """`item_hash("Gunpowder")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:gunpowder", 0)

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
