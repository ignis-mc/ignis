"""FlintAndSteel, ported from Dragonfly `server/item/flint_and_steel.go`.

TODO(player): `UseOnBlock` (igniting blocks, nether portals and fire).
"""

from ..world.item import EncodedItem, Item, item_hash
from .durability import DurabilityInfo, Durable
from .item import MaxCounter


@fieldwise_init
struct FlintAndSteel(Durable, Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """An item used to light blocks on fire."""

    comptime BASE_HASH: UInt64 = item_hash("FlintAndSteel")
    """`item_hash("FlintAndSteel")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def durability_info(self) -> DurabilityInfo:
        """Returns the durability info (Go `DurabilityInfo`): 65 uses."""
        return DurabilityInfo(
            max_durability=65,
            attack_durability=0,
            break_durability=0,
            persistent=False,
        )

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:flint_and_steel", 0)

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
