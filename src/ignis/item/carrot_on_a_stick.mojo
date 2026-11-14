"""CarrotOnAStick, ported from Dragonfly `server/item/carrot_on_a_stick.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .item import MaxCounter


@fieldwise_init
struct CarrotOnAStick(Equatable, ImplicitlyCopyable, Item, MaxCounter):
    """An item that can be used to control saddled pigs."""

    comptime BASE_HASH: UInt64 = item_hash("CarrotOnAStick")
    """`item_hash("CarrotOnAStick")`."""

    def max_count(self) -> Int:
        """Returns the maximum count (Go `MaxCount`)."""
        return 1

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem("minecraft:carrot_on_a_stick", 0)

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
