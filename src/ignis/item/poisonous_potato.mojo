"""PoisonousPotato, ported from Dragonfly `server/item/poisonous_potato.go`.

TODO(player): `Consume` applies `consume_info` to the consumer.
"""

from ..entity.effect import new, SECOND
from ..entity.effect.poison import Poison
from ..world.item import EncodedItem, Item, item_hash
from .item import (
    Consumable,
    ConsumeEffect,
    ConsumeInfo,
    DEFAULT_CONSUME_DURATION,
)


@fieldwise_init
struct PoisonousPotato(Consumable, Equatable, ImplicitlyCopyable, Item):
    """A type of potato that can poison the player."""

    comptime BASE_HASH: UInt64 = item_hash("PoisonousPotato")
    """`item_hash("PoisonousPotato")`."""

    def always_consumable(self) -> Bool:
        """Reports whether the item may be eaten when full."""
        return False

    def consume_duration(self) -> Int:
        """Returns how long eating takes, in milliseconds."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what eating does (Go `Consume`)."""
        return ConsumeInfo(
            2, 1.2, [ConsumeEffect(new(Poison(), 1, 5 * SECOND), 0.6)]
        )

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:poisonous_potato", 0)

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
