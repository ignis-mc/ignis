"""BeetrootSoup, ported from Dragonfly `server/item/beetroot_soup.go`.

TODO(player): `Consume` applies `consume_info` to the consumer.
"""

from ..world.item import EncodedItem, Item, item_hash
from .bowl import Bowl
from .item import Consumable, ConsumeInfo, DEFAULT_CONSUME_DURATION, MaxCounter
from .stack import Stack


@fieldwise_init
struct BeetrootSoup(
    Consumable, Equatable, ImplicitlyCopyable, Item, MaxCounter
):
    """An unstackable food item."""

    comptime BASE_HASH: UInt64 = item_hash("BeetrootSoup")
    """`item_hash("BeetrootSoup")`."""

    def always_consumable(self) -> Bool:
        """Reports whether the item may be eaten when full."""
        return False

    def consume_duration(self) -> Int:
        """Returns how long eating takes, in milliseconds."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what eating does (Go `Consume`)."""
        return ConsumeInfo(6, 7.2, [], Stack(Bowl(), 1))

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:beetroot_soup", 0)

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
