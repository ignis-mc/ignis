"""NetheriteScrap, ported from Dragonfly `server/item/netherite_scrap.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct NetheriteScrap(Equatable, ImplicitlyCopyable, Item):
    """A material smelted from ancient debris, which is found in the Nether."""

    comptime BASE_HASH: UInt64 = item_hash("NetheriteScrap")
    """`item_hash("NetheriteScrap")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:netherite_scrap", 0)

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
