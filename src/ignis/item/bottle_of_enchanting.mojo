"""BottleOfEnchanting, ported from Dragonfly
`server/item/bottle_of_enchanting.go`.

TODO(player): `Use`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct BottleOfEnchanting(Equatable, ImplicitlyCopyable, Item):
    """A bottle that releases experience orbs when thrown."""

    comptime BASE_HASH: UInt64 = item_hash("BottleOfEnchanting")
    """`item_hash("BottleOfEnchanting")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:experience_bottle", 0)

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
