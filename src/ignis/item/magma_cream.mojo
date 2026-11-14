"""MagmaCream, ported from Dragonfly `server/item/magma_cream.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct MagmaCream(Equatable, ImplicitlyCopyable, Item):
    """An item used in brewing to create potions of Fire Resistance, and to
    build magma blocks."""

    comptime BASE_HASH: UInt64 = item_hash("MagmaCream")
    """`item_hash("MagmaCream")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:magma_cream", 0)

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
