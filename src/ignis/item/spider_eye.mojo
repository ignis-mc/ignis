"""SpiderEye, ported from Dragonfly `server/item/spider_eye.go`.

TODO(port): `Consume`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct SpiderEye(Equatable, ImplicitlyCopyable, Item):
    """A poisonous food and brewing item."""

    comptime BASE_HASH: UInt64 = item_hash("SpiderEye")
    """`item_hash("SpiderEye")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:spider_eye", 0)

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
