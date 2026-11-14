"""Bow, ported from Dragonfly `server/item/bow.go`.

TODO(port): `DurabilityInfo`, `Release`, `Requirements`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .enchantment import Enchantable
from .item import MaxCounter
from .smelting_info import Fuel, FuelInfo


@fieldwise_init
struct Bow(Enchantable, Equatable, Fuel, ImplicitlyCopyable, Item, MaxCounter):
    """A ranged weapon that fires arrows."""

    comptime BASE_HASH: UInt64 = item_hash("Bow")
    """`item_hash("Bow")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 10 s."""
        return FuelInfo(10000)

    def enchantment_value(self) -> Int:
        """Returns the enchantability (Go `EnchantmentValue`)."""
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:bow", 0)

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
