"""Elytra, ported from Dragonfly `server/item/elytra.go`.

`Use` (Go `ctx.SwapHeldWithArmour(1)`) is in `server.use.use_item`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .armour import ChestplateType
from .durability import DurabilityInfo, Repairable
from .item import MaxCounter
from .phantom_membrane import PhantomMembrane
from .stack import Stack


@fieldwise_init
struct Elytra(
    ChestplateType, Equatable, ImplicitlyCopyable, Item, MaxCounter, Repairable
):
    """A pair of rare wings found in end ships that are the only single-item
    source of flight in Survival mode."""

    comptime BASE_HASH: UInt64 = item_hash("Elytra")
    """`item_hash("Elytra")`."""

    def durability_info(self) -> DurabilityInfo:
        """Returns the durability info (Go `DurabilityInfo`): 433, persistent.
        """
        return DurabilityInfo(
            max_durability=433,
            attack_durability=0,
            break_durability=0,
            persistent=True,
        )

    def repairable_by(self, i: Stack) -> Bool:
        """Reports whether the stack is phantom membrane (Go `RepairableBy`)."""
        if case .Some(it) = i.item():
            return it.is_a[PhantomMembrane]()
        return False

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`): 1."""
        return 1

    def chestplate(self) -> Bool:
        """Marks the item as worn in the chestplate slot (Go `Chestplate`)."""
        return True

    def defence_points(self) -> Float64:
        """Returns the defence points (Go `DefencePoints`): 0."""
        return 0

    def toughness(self) -> Float64:
        """Returns the toughness (Go `Toughness`): 0."""
        return 0

    def knock_back_resistance(self) -> Float64:
        """Returns the knock-back resistance (Go `KnockBackResistance`): 0."""
        return 0

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
