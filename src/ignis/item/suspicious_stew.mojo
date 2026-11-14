"""SuspiciousStew, ported from Dragonfly `server/item/suspicious_stew.go`.

`Consume` is `server.use.consume` applying `consume_info`.
"""

from ..world.item import EncodedItem, Item, item_hash
from .bowl import Bowl
from .item import (
    DEFAULT_CONSUME_DURATION,
    Consumable,
    ConsumeEffect,
    ConsumeInfo,
    MaxCounter,
)
from .stack import Stack
from .suspicious_stew_type import StewType, stew_types


struct SuspiciousStew(
    Consumable, Equatable, ImplicitlyCopyable, Item, MaxCounter
):
    """A food item that can give the player a status effect depending on its
    ingredients."""

    comptime BASE_HASH: UInt64 = item_hash("SuspiciousStew")
    """`item_hash("SuspiciousStew")`."""

    var type: StewType
    """The type of the stew, which decides its effects."""

    def __init__(out self, *, type: StewType = StewType.NIGHT_VISION_POPPY):
        """Creates the stew (Go `SuspiciousStew{Type: ...}`)."""
        self.type = type

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def always_consumable(self) -> Bool:
        """Reports whether the item may be eaten when full."""
        return True

    def consume_duration(self) -> Int:
        """Returns how long eating takes, in milliseconds."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what eating does (Go `Consume`)."""
        var effects = List[ConsumeEffect]()
        for e in self.type.effects():
            effects.append(ConsumeEffect(e, 1))
        return ConsumeInfo(6, 7.2, effects^, Stack(Bowl(), 1))

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`): the stew type is the meta."""
        return EncodedItem(
            "minecraft:suspicious_stew", Int16(self.type.uint8())
        )

    def hash(self) -> UInt64:
        """Returns the item hash: the stew type."""
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return SuspiciousStew(type=StewType(Int(hash & 0xFF)))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`)."""
        var out = List[Self]()
        for t in stew_types():
            out.append(SuspiciousStew(type=t))
        return out^
