"""ResinBrick, ported from Dragonfly `server/item/resin_brick.go`.

TODO(port): `TrimMaterial`, `MaterialColour`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct ResinBrick(Equatable, ImplicitlyCopyable, Item):
    """An item used to create resin bricks."""

    comptime BASE_HASH: UInt64 = item_hash("ResinBrick")
    """`item_hash("ResinBrick")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:resin_brick", 0)

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
