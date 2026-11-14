"""DiscFragment, ported from Dragonfly `server/item/disc_fragment.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct DiscFragment(Equatable, ImplicitlyCopyable, Item):
    """A music disc fragment obtained from ancient city loot chests."""

    comptime BASE_HASH: UInt64 = item_hash("DiscFragment")
    """`item_hash("DiscFragment")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:disc_fragment_5", 0)

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
