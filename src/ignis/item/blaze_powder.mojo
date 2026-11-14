"""BlazePowder, ported from Dragonfly `server/item/blaze_powder.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct BlazePowder(Equatable, ImplicitlyCopyable, Item):
    """An item made from a blaze rod obtained from blazes."""

    comptime BASE_HASH: UInt64 = item_hash("BlazePowder")
    """`item_hash("BlazePowder")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:blaze_powder", 0)

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
