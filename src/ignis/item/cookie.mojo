"""Cookie, ported from Dragonfly `server/item/cookie.go`.

TODO(port): `Consume`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import Compostable


@fieldwise_init
struct Cookie(Compostable, Equatable, ImplicitlyCopyable, Item):
    """A food item that can be obtained in large quantities, but do not restore hunger or saturation significantly.
    """

    comptime BASE_HASH: UInt64 = item_hash("Cookie")
    """`item_hash("Cookie")`."""

    def compost_chance(self) -> Float64:
        """Returns the compost chance (Go `CompostChance`)."""
        return 0.85

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:cookie", 0)

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
