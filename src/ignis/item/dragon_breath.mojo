"""DragonBreath, ported from Dragonfly `server/item/dragon_breath.go`."""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct DragonBreath(Equatable, ImplicitlyCopyable, Item):
    """A brewing item that is used solely to make lingering potions."""

    comptime BASE_HASH: UInt64 = item_hash("DragonBreath")
    """`item_hash("DragonBreath")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:dragon_breath", 0)

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
