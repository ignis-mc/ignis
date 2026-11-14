"""FireCharge, ported from Dragonfly `server/item/fire_charge.go`.

TODO(port): `UseOnBlock`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct FireCharge(Equatable, ImplicitlyCopyable, Item):
    """An item that can be used to place fire when used on a block, or shot from
    a dispenser to create a small fireball."""

    comptime BASE_HASH: UInt64 = item_hash("FireCharge")
    """`item_hash("FireCharge")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:fire_charge", 0)

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
