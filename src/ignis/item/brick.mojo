"""Brick, ported from Dragonfly `server/item/brick.go`.

TODO(port): `PotDecoration`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct Brick(Equatable, ImplicitlyCopyable, Item):
    """An item made from clay, and is used for making bricks and flower pots."""

    comptime BASE_HASH: UInt64 = item_hash("Brick")
    """`item_hash("Brick")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:brick", 0)

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
