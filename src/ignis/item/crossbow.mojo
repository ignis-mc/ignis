"""Crossbow, ported from Dragonfly `server/item/crossbow.go`.

TODO(port): `Charge`, `ContinueCharge`, `chargeDuration`, `findProjectile`, `ReleaseCharge`, `CanCharge`, `shoot`, `applyDamage`, `DurabilityInfo`, `DecodeNBT`, `EncodeNBT`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .enchantment import Enchantable
from .item import MaxCounter
from .smelting_info import Fuel, FuelInfo


@fieldwise_init
struct Crossbow(
    Enchantable, Equatable, Fuel, ImplicitlyCopyable, Item, MaxCounter
):
    """A ranged weapon similar to a bow that uses arrows or fireworks as
    ammunition."""

    comptime BASE_HASH: UInt64 = item_hash("Crossbow")
    """`item_hash("Crossbow")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def fuel_info(self) -> FuelInfo:
        """Returns the fuel info (Go `FuelInfo`): burns 15 s."""
        return FuelInfo(15000)

    def enchantment_value(self) -> Int:
        """Returns the enchantability (Go `EnchantmentValue`)."""
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:crossbow", 0)

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
