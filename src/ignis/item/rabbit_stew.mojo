"""RabbitStew, ported from Dragonfly `server/item/rabbit_stew.go`.

TODO(port): `Consume`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import MaxCounter


@fieldwise_init
struct RabbitStew(Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """A food item that can be eaten by the player."""

    comptime BASE_HASH: UInt64 = item_hash("RabbitStew")
    """`item_hash("RabbitStew")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:rabbit_stew", 0)

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
