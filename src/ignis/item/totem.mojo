"""Totem, ported from Dragonfly `server/item/totem.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .item import MaxCounter
from .item import OffHand


@fieldwise_init
struct Totem(Equatable, ImplicitlyCopyable, Item, MaxCounter, OffHand):
    """An uncommon combat item that can save holders from death."""

    comptime BASE_HASH: UInt64 = item_hash("Totem")
    """`item_hash("Totem")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def off_hand(self) -> Bool:
        """Reports that the item may be held in the off hand (Go `OffHand`)."""
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:totem_of_undying", 0)

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
