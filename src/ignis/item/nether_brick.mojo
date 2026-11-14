"""NetherBrick, ported from Dragonfly `server/item/nether_brick.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct NetherBrick(Equatable, ImplicitlyCopyable, Item):
    """An item made by smelting netherrack in a furnace."""

    comptime BASE_HASH: UInt64 = item_hash("NetherBrick")
    """`item_hash("NetherBrick")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:netherbrick", 0)

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
