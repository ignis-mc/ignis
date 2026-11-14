"""Rabbit, ported from Dragonfly `server/item/rabbit.go`.

TODO(player): `Consume` applies `consume_info` to the consumer.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import Consumable, ConsumeInfo, DEFAULT_CONSUME_DURATION
from .smelting_info import Smeltable, SmeltInfo
from .stack import Stack


struct Rabbit(Consumable, Equatable, ImplicitlyCopyable, Item, Smeltable):
    """A food item obtained from rabbits; it can be cooked."""

    comptime BASE_HASH: UInt64 = item_hash("Rabbit")
    """`item_hash("Rabbit")`."""

    var cooked: Bool
    """Whether the item is cooked."""

    def __init__(out self, *, cooked: Bool = False):
        """Creates the item; raw by default (Go `Rabbit{}`)."""
        self.cooked = cooked

    def always_consumable(self) -> Bool:
        """Reports whether the item may be eaten when full."""
        return False

    def consume_duration(self) -> Int:
        """Returns how long eating takes, in milliseconds."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what eating does (Go `Consume`)."""
        if self.cooked:
            return ConsumeInfo(5, 6)
        return ConsumeInfo(3, 1.8)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`): cooks the raw item."""
        if self.cooked:
            return SmeltInfo()
        return SmeltInfo(Stack(Rabbit(cooked=True), 1), 0.35, food=True)

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        if self.cooked:
            return EncodedItem("minecraft:cooked_rabbit", 0)
        return EncodedItem("minecraft:rabbit", 0)

    def hash(self) -> UInt64:
        """Returns the item hash: 1 if cooked."""
        return UInt64(1) if self.cooked else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Rabbit(cooked=hash & 1 != 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Rabbit(cooked=True), Rabbit()]
