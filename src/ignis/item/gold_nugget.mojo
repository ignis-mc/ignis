"""GoldNugget, ported from Dragonfly `server/item/gold_nugget.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct GoldNugget(Equatable, ImplicitlyCopyable, Item):
    """An item used to craft gold ingots & other various gold items."""

    comptime BASE_HASH: UInt64 = item_hash("GoldNugget")
    """`item_hash("GoldNugget")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:gold_nugget", 0)

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
