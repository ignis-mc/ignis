"""PotterySherd, ported from Dragonfly `server/item/pottery_sherd.go`."""

from ..world.item import EncodedItem, Item, item_hash
from .sherd_type import SherdType, sherd_types


struct PotterySherd(Equatable, ImplicitlyCopyable, Item):
    """An item that can be found from brushing suspicious sand or gravel."""

    comptime BASE_HASH: UInt64 = item_hash("PotterySherd")
    """`item_hash("PotterySherd")`."""

    var type: SherdType
    """The sherd type."""

    def __init__(out self, *, type: SherdType = SherdType(0)):
        """Creates the item; omitted fields take Go zero values."""
        self.type = type

    def __eq__(self, other: Self) -> Bool:
        """Compares two items."""
        return self.type == other.type

    def pot_decoration(self) -> Bool:
        """Reports that the sherd decorates pots (Go `PotDecoration`)."""
        return True

    def encode_item(self) -> EncodedItem:
        """Encodes the item (Go `EncodeItem`)."""
        return EncodedItem(
            String("minecraft:", self.type.name(), "_pottery_sherd"), 0
        )

    def hash(self) -> UInt64:
        """Returns the item hash: the sherd type's index."""
        return UInt64(self.type.uint8())

    @staticmethod
    def from_hash(hash: UInt64) -> Self:
        """Rebuilds the item from its hash."""
        return Self(type=SherdType(Int(hash)))

    @staticmethod
    def all_items() -> List[Self]:
        """Returns the registered values (Go `register.go`): every sherd type.
        """
        var out = List[Self]()
        for t in sherd_types():
            out.append(Self(type=t))
        return out^
