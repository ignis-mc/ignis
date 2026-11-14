"""Elytra, ported from Dragonfly `server/item/elytra.go`.

TODO(port): `Use`, `DurabilityInfo`, `RepairableBy`, `Chestplate`, `DefencePoints`, `Toughness`, `KnockBackResistance`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import MaxCounter


@fieldwise_init
struct Elytra(Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """A pair of rare wings found in end ships that are the only single-item
    source of flight in Survival mode."""

    comptime BASE_HASH: UInt64 = item_hash("Elytra")
    """`item_hash("Elytra")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:elytra", 0)

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
