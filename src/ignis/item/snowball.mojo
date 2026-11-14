"""Snowball, ported from Dragonfly `server/item/snowball.go`.

TODO(port): `Use`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import MaxCounter


@fieldwise_init
struct Snowball(Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """A throwable combat item obtained through shovelling snow."""

    comptime BASE_HASH: UInt64 = item_hash("Snowball")
    """`item_hash("Snowball")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 16

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:snowball", 0)

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
