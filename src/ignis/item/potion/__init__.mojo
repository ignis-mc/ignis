"""Potions: the potion types of Dragonfly `server/item/potion` (in
`potion.mojo`) and the `Potion` item of `server/item/potion.go`.

Mojo cannot have a module and a package with the same name, so Go's
`item/potion.go` lives in this package's `__init__`.

`server.use.consume` applies `consume_info` (Go `Consume`).
"""

from ...world.item import EncodedItem, Item, item_hash
from ..glass_bottle import GlassBottle
from ..item import (
    DEFAULT_CONSUME_DURATION,
    Consumable,
    ConsumeEffect,
    ConsumeInfo,
    MaxCounter,
)
from ..stack import Stack
from .potion import Potion as PotionType
from .potion import all_potions


struct Potion(Consumable, Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """An item that grants effects on consumption."""

    comptime BASE_HASH: UInt64 = item_hash("Potion")
    """`item_hash("Potion")`."""

    var type: PotionType
    """The type of the potion."""

    def __init__(out self, *, type: PotionType = PotionType()):
        """Creates the item; omitted fields take Go zero values."""
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two potions by type."""
        return self.type == other.type

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def always_consumable(self) -> Bool:
        """Reports that potions may always be drunk (Go `AlwaysConsumable`)."""
        return True

    def consume_duration(self) -> Int:
        """Returns how long drinking takes (Go `ConsumeDuration`)."""
        return DEFAULT_CONSUME_DURATION

    def consume_info(self) -> ConsumeInfo:
        """Returns what drinking does (Go `Consume`): the type's effects."""
        var effects = List[ConsumeEffect]()
        for e in self.type.effects():
            effects.append(ConsumeEffect(e, 1.0))
        return ConsumeInfo(0, 0, effects^, Stack(GlassBottle(), 1))

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`): the type's ID is the meta."""
        return EncodedItem("minecraft:potion", Int16(self.type.uint8()))

    def hash(self) -> UInt64:
        """Returns the item hash: the potion ID."""
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self(type=PotionType(Int(hash)))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`): every type."""
        var out = List[Self]()
        for p in all_potions():
            out.append(Self(type=p))
        return out^
