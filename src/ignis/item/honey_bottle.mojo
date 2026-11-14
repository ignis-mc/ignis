"""HoneyBottle, ported from Dragonfly `server/item/honey_bottle.go`.

`Consume` is `server.use.consume` applying `consume_info`.
"""

from ..entity.effect.poison import Poison
from ..world.item import EncodedItem, Item, item_hash
from .glass_bottle import GlassBottle
from .item import Consumable, ConsumeInfo, DEFAULT_CONSUME_DURATION, MaxCounter
from .stack import Stack


@fieldwise_init
struct HoneyBottle(Consumable, Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """A consumable item that cures poison."""

    comptime BASE_HASH: UInt64 = item_hash("HoneyBottle")
    """`item_hash("HoneyBottle")`."""

    def always_consumable(self) -> Bool:
        """Reports whether the item may be eaten when full."""
        return True

    def consume_duration(self) -> Int:
        """Returns how long eating takes, in milliseconds."""
        return DEFAULT_CONSUME_DURATION * 5 // 4

    def consume_info(self) -> ConsumeInfo:
        """Returns what eating does (Go `Consume`)."""
        var info = ConsumeInfo(6, 1.2, [], Stack(GlassBottle(), 1))
        info.removed_effects.append(Poison.ID)
        return info^

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 16

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:honey_bottle", 0)

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
