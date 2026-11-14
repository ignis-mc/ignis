"""Chicken, ported from Dragonfly `server/item/chicken.go`.

`Consume` is `server.use.consume` applying `consume_info`.
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
from .smelting_info import Smeltable, SmeltInfo
from .stack import Stack


struct Chicken(Consumable, Equatable, ImplicitlyCopyable, Item, Smeltable):
    """A food item obtained from chickens; it can be cooked."""

    comptime BASE_HASH: UInt64 = item_hash("Chicken")
    """`item_hash("Chicken")`."""

    var cooked: Bool
    """Whether the item is cooked."""

    def __init__(out self, *, cooked: Bool = False):
        """Creates the item; raw by default (Go `Chicken{}`)."""
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
            return ConsumeInfo(6, 7.2)
        return ConsumeInfo(
            2, 1.2, [ConsumeEffect(new(Hunger(), 1, 30 * SECOND), 0.3)]
        )

    def smelt_info(self) -> SmeltInfo:
        """Returns the smelt info (Go `SmeltInfo`): cooks the raw item."""
        if self.cooked:
            return SmeltInfo()
        return SmeltInfo(Stack(Chicken(cooked=True), 1), 0.35, food=True)

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        if self.cooked:
            return EncodedItem("minecraft:cooked_chicken", 0)
        return EncodedItem("minecraft:chicken", 0)

    def hash(self) -> UInt64:
        """Returns the item hash: 1 if cooked."""
        return UInt64(1) if self.cooked else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Chicken(cooked=hash & 1 != 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Chicken(cooked=True), Chicken()]
