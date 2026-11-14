"""RottenFlesh, ported from Dragonfly `server/item/rotten_flesh.go`.

TODO(player): `Consume` applies `consume_info` to the consumer.
"""

from ..entity.effect import new, SECOND
from ..entity.effect.hunger import Hunger
from ..world.item import EncodedItem, Item, item_hash
from .item import (
    Consumable,
    ConsumeEffect,
    ConsumeInfo,
    DEFAULT_CONSUME_DURATION,
)


@fieldwise_init
struct RottenFlesh(Consumable, Equatable, ImplicitlyCopyable, Item):
    """A food item that can be eaten, at the risk of hunger."""

    comptime BASE_HASH: UInt64 = item_hash("RottenFlesh")
    """`item_hash("RottenFlesh")`."""

    def always_consumable(self) -> Bool:
        """Reports whether the item may be eaten when full."""
        return False

    def consume_duration(self) -> Int:
        """Returns how long eating takes, in milliseconds."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what eating does (Go `Consume`)."""
        return ConsumeInfo(
            4, 0.8, [ConsumeEffect(new(Hunger(), 1, 30 * SECOND), 0.8)]
        )

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:rotten_flesh", 0)

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
