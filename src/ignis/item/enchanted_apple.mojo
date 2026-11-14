"""EnchantedApple, ported from Dragonfly `server/item/enchanted_apple.go`.

TODO(port): `AlwaysConsumable`, `ConsumeDuration`, `Consume`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct EnchantedApple(Equatable, ImplicitlyCopyable, Item):
    """A rare variant of the golden apple that has stronger effects."""

    comptime BASE_HASH: UInt64 = item_hash("EnchantedApple")
    """`item_hash("EnchantedApple")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:enchanted_golden_apple", 0)

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
