"""PoppedChorusFruit, ported from Dragonfly `server/item/popped_chorus_fruit.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct PoppedChorusFruit(Equatable, ImplicitlyCopyable, Item):
    """An item obtained by smelting chorus fruit, and used to craft end rods and purpur blocks.
    """

    comptime BASE_HASH: UInt64 = item_hash("PoppedChorusFruit")
    """`item_hash("PoppedChorusFruit")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:popped_chorus_fruit", 0)

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
