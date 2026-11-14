"""RottenFlesh, ported from Dragonfly `server/item/rotten_flesh.go`.

TODO(port): `Consume`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct RottenFlesh(Equatable, ImplicitlyCopyable, Item):
    """A food item that can be eaten by the player, at the high risk of
    inflicting hunger."""

    comptime BASE_HASH: UInt64 = item_hash("RottenFlesh")
    """`item_hash("RottenFlesh")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:rotten_flesh", 0)

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
