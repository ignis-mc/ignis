"""GoldenApple, ported from Dragonfly `server/item/golden_apple.go`.

TODO(port): `AlwaysConsumable`, `ConsumeDuration`, `Consume`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct GoldenApple(Equatable, ImplicitlyCopyable, Item):
    """A special food item that bestows beneficial effects."""

    comptime BASE_HASH: UInt64 = item_hash("GoldenApple")
    """`item_hash("GoldenApple")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:golden_apple", 0)

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
