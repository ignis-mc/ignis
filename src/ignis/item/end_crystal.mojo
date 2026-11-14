"""EndCrystal, ported from Dragonfly `server/item/end_crystal.go`.

TODO(port): `UseOnBlock`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct EndCrystal(Equatable, ImplicitlyCopyable, Item):
    """An item that can be placed on obsidian or bedrock to spawn an End crystal entity.
    """

    comptime BASE_HASH: UInt64 = item_hash("EndCrystal")
    """`item_hash("EndCrystal")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:end_crystal", 0)

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
