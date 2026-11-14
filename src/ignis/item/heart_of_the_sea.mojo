"""HeartOfTheSea, ported from Dragonfly `server/item/heart_of_the_sea.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct HeartOfTheSea(Equatable, ImplicitlyCopyable, Item):
    """A rare item that can be crafted into a conduit."""

    comptime BASE_HASH: UInt64 = item_hash("HeartOfTheSea")
    """`item_hash("HeartOfTheSea")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:heart_of_the_sea", 0)

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
