"""BoneMeal, ported from Dragonfly `server/item/bone_meal.go`.

TODO(player): `UseOnBlock`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct BoneMeal(Equatable, ImplicitlyCopyable, Item):
    """An item used to force growth in plants & crops."""

    comptime BASE_HASH: UInt64 = item_hash("BoneMeal")
    """`item_hash("BoneMeal")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:bone_meal", 0)

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
