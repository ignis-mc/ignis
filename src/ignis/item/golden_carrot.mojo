"""GoldenCarrot, ported from Dragonfly `server/item/golden_carrot.go`.

TODO(port): `Consume`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct GoldenCarrot(Equatable, ImplicitlyCopyable, Item):
    """A valuable food item and brewing ingredient."""

    comptime BASE_HASH: UInt64 = item_hash("GoldenCarrot")
    """`item_hash("GoldenCarrot")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:golden_carrot", 0)

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
