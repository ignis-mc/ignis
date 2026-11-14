"""Beef, ported from Dragonfly `server/item/beef.go`.

`Consume` is described by `consume_info` (TODO(player): apply it to the
consumer).
"""

from ..world.item import EncodedItem, Item, item_hash
from .item import DEFAULT_CONSUME_DURATION, Consumable, ConsumeInfo
from .smelting_info import Smeltable, SmeltInfo
from .stack import Stack


@fieldwise_init
struct Beef(Consumable, Equatable, ImplicitlyCopyable, Item, Smeltable):
    """A food item obtained from cows. It can be cooked in a furnace, smoker,
    or campfire."""

    comptime BASE_HASH: UInt64 = item_hash("Beef")
    """`item_hash("Beef")`."""

    var cooked: Bool
    """Whether the beef is cooked."""

    def __init__(out self):
        """Creates raw beef (Go `Beef{}`)."""
        self.cooked = False

    def always_consumable(self) -> Bool:
        """Reports whether the item may be eaten with a full food bar (Go
        `defaultFood`).
        """
        return False

    def consume_duration(self) -> Int:
        """Returns how long eating takes (Go `defaultFood`)."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what eating the beef does (Go `Consume`)."""
        if self.cooked:
            return ConsumeInfo(8, 12.8)
        return ConsumeInfo(3, 1.8)

    def smelt_info(self) -> SmeltInfo:
        """Returns what smelting the beef gives (Go `SmeltInfo`)."""
        if self.cooked:
            return SmeltInfo()
        return SmeltInfo(Stack(Beef(cooked=True), 1), 0.35, food=True)

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        if self.cooked:
            return EncodedItem("minecraft:cooked_beef", 0)
        return EncodedItem("minecraft:beef", 0)

    def hash(self) -> UInt64:
        """Returns the item hash."""
        return UInt64(1) if self.cooked else UInt64(0)

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Beef(cooked=hash & 1 != 0)

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        return [Beef(cooked=True), Beef()]
