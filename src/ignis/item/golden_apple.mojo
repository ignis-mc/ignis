"""GoldenApple, ported from Dragonfly `server/item/golden_apple.go`.

TODO(player): `Consume` applies `consume_info` to the consumer and raises
its absorption to `max(prev, min(prev+4, 16))`.
"""

from ..entity.effect import new, SECOND
from ..entity.effect.absorption import Absorption
from ..entity.effect.regeneration import Regeneration
from ..world.item import EncodedItem, Item, item_hash
from .item import (
    Consumable,
    ConsumeEffect,
    ConsumeInfo,
    DEFAULT_CONSUME_DURATION,
)


@fieldwise_init
struct GoldenApple(Consumable, Equatable, ImplicitlyCopyable, Item):
    """A special food item that bestows beneficial effects."""

    comptime BASE_HASH: UInt64 = item_hash("GoldenApple")
    """`item_hash("GoldenApple")`."""

    def always_consumable(self) -> Bool:
        """Reports whether the item may be eaten when full."""
        return True

    def consume_duration(self) -> Int:
        """Returns how long eating takes, in milliseconds."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what eating does (Go `Consume`)."""
        return ConsumeInfo(
            4,
            9.6,
            [
                ConsumeEffect(new(Absorption(), 1, 120 * SECOND), 1),
                ConsumeEffect(new(Regeneration(), 2, 5 * SECOND), 1),
            ],
        )

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:golden_apple", 0)

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
