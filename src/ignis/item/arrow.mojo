"""Arrow, ported from Dragonfly `server/item/arrow.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .item import OffHand
from .potion.potion import Potion, all_potions


struct Arrow(Equatable, ImplicitlyCopyable, Item, OffHand):
    """Ammunition for bows, crossbows and dispensers. Arrows can be tipped to
    imbue status effects on players and mobs."""

    comptime BASE_HASH: UInt64 = item_hash("Arrow")
    """`item_hash("Arrow")`."""

    var tip: Potion
    """The potion effect the arrow is tipped with."""

    def __init__(out self, *, tip: Potion = Potion()):
        """Creates the item; omitted fields take Go zero values."""
        self.tip = tip

    def __eq__(self, other: Self) -> Bool:
        """Compares two arrows by tip."""
        return self.tip == other.tip

    def off_hand(self) -> Bool:
        """Reports that arrows may be held in the off hand (Go `OffHand`)."""
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`): meta is the tip's ID plus one
        for tips above 4 (awkward), 0 otherwise."""
        var tip = self.tip.uint8()
        if tip > 4:
            return EncodedItem("minecraft:arrow", Int16(tip) + 1)
        return EncodedItem("minecraft:arrow", 0)

    def hash(self) -> UInt64:
        """Returns the item hash: the tip's potion ID."""
        return UInt64(self.tip.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self(tip=Potion(Int(hash)))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`): untipped, then
        every tip after awkward."""
        var out: List[Self] = [Self()]
        var potions = all_potions()
        for i in range(5, len(potions)):
            out.append(Self(tip=potions[i]))
        return out^
