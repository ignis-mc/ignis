"""GoldenCarrot, ported from Dragonfly `server/item/golden_carrot.go`.

TODO(player): `Consume` applies `consume_info` to the consumer.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import Consumable, ConsumeInfo, DEFAULT_CONSUME_DURATION


@fieldwise_init
struct GoldenCarrot(Consumable, Equatable, ImplicitlyCopyable, Item):
    """A valuable food item and brewing ingredient."""

    comptime BASE_HASH: UInt64 = item_hash("GoldenCarrot")
    """`item_hash("GoldenCarrot")`."""

    def always_consumable(self) -> Bool:
        """Reports whether the item may be eaten when full."""
        return False

    def consume_duration(self) -> Int:
        """Returns how long eating takes, in milliseconds."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what eating does (Go `Consume`)."""
        return ConsumeInfo(6, 14.4)

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:golden_carrot", 0)

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
