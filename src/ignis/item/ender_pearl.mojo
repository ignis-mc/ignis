"""EnderPearl, ported from Dragonfly `server/item/ender_pearl.go`.

TODO(player): `Use`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import Cooldown, MaxCounter


@fieldwise_init
struct EnderPearl(Cooldown, Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """A smooth, greenish-blue item used to teleport and to make an eye of
    ender."""

    comptime BASE_HASH: UInt64 = item_hash("EnderPearl")
    """`item_hash("EnderPearl")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 16

    def cooldown(self) -> Int:
        """Returns the cooldown (Go `Cooldown`): 1 s."""
        return 1000

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:ender_pearl", 0)

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
