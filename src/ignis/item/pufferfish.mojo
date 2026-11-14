"""Pufferfish, ported from Dragonfly `server/item/pufferfish.go`.

`Consume` is `server.use.consume` applying `consume_info`.
"""

from ..entity.effect import new, SECOND
from ..entity.effect.hunger import Hunger
from ..entity.effect.nausea import Nausea
from ..entity.effect.poison import Poison
from ..world.item import EncodedItem, Item, item_hash
from .item import (
    Consumable,
    ConsumeEffect,
    ConsumeInfo,
    DEFAULT_CONSUME_DURATION,
)


@fieldwise_init
struct Pufferfish(Consumable, Equatable, ImplicitlyCopyable, Item):
    """A poisonous type of fish."""

    comptime BASE_HASH: UInt64 = item_hash("Pufferfish")
    """`item_hash("Pufferfish")`."""

    def always_consumable(self) -> Bool:
        """Reports whether the item may be eaten when full."""
        return False

    def consume_duration(self) -> Int:
        """Returns how long eating takes, in milliseconds."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what eating does (Go `Consume`)."""
        return ConsumeInfo(
            1,
            0.2,
            [
                ConsumeEffect(new(Hunger(), 3, 15 * SECOND), 1),
                ConsumeEffect(new(Poison(), 2, 60 * SECOND), 1),
                ConsumeEffect(new(Nausea(), 2, 15 * SECOND), 1),
            ],
        )

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:pufferfish", 0)

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
