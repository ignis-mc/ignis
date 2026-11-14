"""TurtleShell, ported from Dragonfly `server/item/turtle_shell.go`.

TODO(player): `Use` (Go `ctx.SwapHeldWithArmour(0)`).
"""

from ..world.item import EncodedItem, Item, item_hash
from .armour import HelmetType
from .durability import DurabilityInfo, Repairable
from .enchantment import Enchantable
from .item import MaxCounter
from .scute import Scute
from .stack import Stack


@fieldwise_init
struct TurtleShell(
    Enchantable,
    Equatable,
    HelmetType,
    ImplicitlyCopyable,
    Item,
    MaxCounter,
    Repairable,
):
    """A helmet that gives the Water Breathing effect, also used in brewing."""

    comptime BASE_HASH: UInt64 = item_hash("TurtleShell")
    """`item_hash("TurtleShell")`."""

    def durability_info(self) -> DurabilityInfo:
        """Returns the durability info (Go `DurabilityInfo`): 276."""
        return DurabilityInfo(
            max_durability=276,
            attack_durability=0,
            break_durability=0,
            persistent=False,
        )

    def repairable_by(self, i: Stack) -> Bool:
        """Reports whether the stack is a scute (Go `RepairableBy`)."""
        if case .Some(it) = i.item():
            return it.is_a[Scute]()
        return False

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`): 1."""
        return 1

    def defence_points(self) -> Float64:
        """Returns the defence points (Go `DefencePoints`): 2."""
        return 2

    def toughness(self) -> Float64:
        """Returns the toughness (Go `Toughness`): 0."""
        return 0

    def knock_back_resistance(self) -> Float64:
        """Returns the knock-back resistance (Go `KnockBackResistance`): 0."""
        return 0

    def enchantment_value(self) -> Int:
        """Returns the enchantability (Go `EnchantmentValue`): 9."""
        return 9

    def helmet(self) -> Bool:
        """Marks the item as worn in the helmet slot (Go `Helmet`)."""
        return True

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
