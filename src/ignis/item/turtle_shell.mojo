"""TurtleShell, ported from Dragonfly `server/item/turtle_shell.go`.

TODO(port): `Use`, `DurabilityInfo`, `RepairableBy`, `DefencePoints`, `Toughness`, `KnockBackResistance`, `Helmet`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .enchantment import Enchantable
from .item import MaxCounter


@fieldwise_init
struct TurtleShell(
    Enchantable, Equatable, ImplicitlyCopyable, Item, MaxCounter
):
    """Items that are used for brewing or as a helmet to give the player the Water Breathing status effect.
    """

    comptime BASE_HASH: UInt64 = item_hash("TurtleShell")
    """`item_hash("TurtleShell")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def enchantment_value(self) -> Int:
        """Returns the enchantability (Go `EnchantmentValue`)."""
        return 9

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:turtle_helmet", 0)

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
