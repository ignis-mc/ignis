"""Cod, ported from Dragonfly `server/item/cod.go`.

TODO(player): `Consume` applies `consume_info` to the consumer.
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import Consumable, ConsumeInfo, DEFAULT_CONSUME_DURATION
from .smelting_info import Smeltable, SmeltInfo
from .stack import Stack


struct Cod(Consumable, Equatable, ImplicitlyCopyable, Item, Smeltable):
    """A food item obtained from cod; it can be cooked."""

    comptime BASE_HASH: UInt64 = item_hash("Cod")
    """`item_hash("Cod")`."""

    var cooked: Bool
    """Whether the item is cooked."""

    def __init__(out self, *, cooked: Bool = False):
        """Creates the item; raw by default (Go `Cod{}`)."""
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
        return ConsumeInfo(2, 0.4)

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`): cooks the raw item."""
        if self.cooked:
            return SmeltInfo()
        return SmeltInfo(Stack(Cod(cooked=True), 1), 0.35, food=True)

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        if self.cooked:
            return EncodedItem("minecraft:cooked_cod", 0)
        return EncodedItem("minecraft:cod", 0)

    def hash(self) -> UInt64:
        """Returns the item hash: 1 if cooked."""
        return UInt64(1) if self.cooked else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Cod(cooked=hash & 1 != 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Cod(cooked=True), Cod()]
