"""Crossbow, ported from Dragonfly `server/item/crossbow.go`.

TODO(player): `Charge`, `ContinueCharge`, `chargeDuration`,
`findProjectile`, `ReleaseCharge`, `CanCharge`, `shoot`, `applyDamage`.
TODO(world-runtime): `EncodeNBT`/`DecodeNBT` (`chargedItem`), which need
the disk form of stack NBT.
"""

from ..world.item import EncodedItem, Item, item_hash
from .durability import DurabilityInfo, Durable
from .enchantment import Enchantable
from .item import MaxCounter
from .smelting_info import Fuel, FuelInfo
from .stack import Stack


struct Crossbow(Durable, Enchantable, Equatable, Fuel, Item, MaxCounter):
    """A ranged weapon similar to a bow that uses arrows or fireworks as
    ammunition."""

    comptime BASE_HASH: UInt64 = item_hash("Crossbow")
    """`item_hash("Crossbow")`."""

    var item: Stack
    """The projectile the crossbow is charged with; empty when uncharged.
    Not part of the hash."""

    def __init__(out self, *, var item: Stack = Stack()):
        """Creates the item; omitted fields take Go zero values."""
        self.item = item^

    def __eq__(self, other: Self) -> Bool:
        """Compares two crossbows, with their charged items."""
        return self.item == other.item

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def durability_info(self) -> DurabilityInfo:
        """Returns the durability info (Go `DurabilityInfo`): 464 uses."""
        return DurabilityInfo(
            max_durability=464,
            attack_durability=0,
            break_durability=0,
            persistent=False,
        )

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
        """Returns the item hash; the charged item is not hashed."""
        return 0

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash: an uncharged crossbow."""
        return Self()

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Self()]
