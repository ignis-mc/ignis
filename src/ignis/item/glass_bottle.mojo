"""GlassBottle, ported from Dragonfly `server/item/glass_bottle.go`.

TODO(player): `UseOnBlock`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct GlassBottle(Equatable, ImplicitlyCopyable, Item):
    """An item that can hold various liquids."""

    comptime BASE_HASH: UInt64 = item_hash("GlassBottle")
    """`item_hash("GlassBottle")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:glass_bottle", 0)

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
