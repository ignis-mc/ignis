"""PoisonousPotato, ported from Dragonfly `server/item/poisonous_potato.go`.

TODO(port): `Consume`.
"""

from ..world.item import EncodedItem, Item, item_hash


@fieldwise_init
struct PoisonousPotato(Equatable, ImplicitlyCopyable, Item):
    """A type of potato that can poison the player."""

    comptime BASE_HASH: UInt64 = item_hash("PoisonousPotato")
    """`item_hash("PoisonousPotato")`."""

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:poisonous_potato", 0)

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
